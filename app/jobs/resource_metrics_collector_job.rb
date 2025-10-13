require 'json'
require 'shellwords'

class ResourceMetricsCollectorJob < ApplicationJob
  queue_as :default

  def perform(server_id)
    start_time = Time.current
    server = Server.find(server_id)
    Rails.logger.info "[ResourceMetrics] #{server.name}: Starting collection..."
    
    key = server.private_key&.private_key
    unless key.present?
      Rails.logger.warn "[ResourceMetrics] #{server.name}: No SSH key, skipping"
      return
    end

    client = SshClient.new(host: server.ip, user: server.user, port: server.port || 22, private_key: key)

    # List containers via Docker Engine API
    Rails.logger.info "[ResourceMetrics] #{server.name}: Fetching container list..."
    _code, list_out, _ = client.exec!("curl --silent --unix-socket /var/run/docker.sock http://localhost/v1.43/containers/json")
    containers = JSON.parse(list_out) rescue []
    Rails.logger.info "[ResourceMetrics] #{server.name}: Found #{containers.count} containers"

    # Map container IDs to resources by label
    id_to_resource = {}
    containers.each do |c|
      container_name = c['Names']&.first&.sub(/^\//, '') || ''
      labels = c.dig('Labels') || {}
      coolify_type = labels['coolify.type']
      
      # Try coolify.name first
      resource_uuid = labels['coolify.name']
      
      # Handle variant formats where coolify.name contains full container name or prefix
      if resource_uuid.present?
        # If coolify.name looks like a full container name (has dash and numbers), extract UUID
        # e.g., "app-x4kgs0sks8ws8occo48sc8sk-160623313064" → "x4kgs0sks8ws8occo48sc8sk"
        if resource_uuid.include?('-') && resource_uuid =~ /-\d{12,}$/
          # Remove prefix (app-, service-, etc) and numeric suffix
          parts = resource_uuid.split('-')
          # Find the part that looks like a Coolify UUID (24-28 chars, alphanumeric)
          uuid_candidate = parts.find { |p| p.length >= 24 && p.length <= 28 && p.match?(/^[a-z0-9]+$/) }
          resource_uuid = uuid_candidate if uuid_candidate
        end
      end
      
      # Databases: use container name as UUID (already correct format)
      if resource_uuid.nil? && coolify_type == 'database'
        resource_uuid = container_name
      end
      
      # Services: try serviceId or service name patterns
      if resource_uuid.nil? && coolify_type == 'service'
        # Services might use coolify.serviceId or be named differently
        # Extract from container name if it matches service pattern
        resource_uuid = container_name if container_name.match?(/^[a-z0-9]{24,28}$/)
      end
      
      next unless resource_uuid.present?
      resource = server.resources.find_by(uuid: resource_uuid)
      
      # Debug logging
      if resource
        Rails.logger.debug "[ResourceMetrics]   ✓ #{container_name} → #{resource.name}"
        id_to_resource[c['Id']] = resource
      else
        Rails.logger.warn "[ResourceMetrics]   ✗ #{container_name} (uuid: #{resource_uuid}, type: #{coolify_type}) - not in DB"
      end
    end
    
    Rails.logger.info "[ResourceMetrics] #{server.name}: Matched #{id_to_resource.count}/#{containers.count} containers to resources"

    now = Time.current
    total = id_to_resource.count
    
    # BULK COLLECT ALL STATS IN 2 SSH CALLS (instead of ~3 per container)
    Rails.logger.info "[ResourceMetrics] #{server.name}: Collecting bulk stats for #{total} containers..."
    
    # 1. Get ALL container stats at once (~5s for 392 containers)
    Rails.logger.info "[ResourceMetrics] #{server.name}: → Fetching docker stats (bulk)..."
    stats_start = Time.current
    _code, stats_out, stats_err = client.exec!('docker stats --no-stream --format json 2>&1', timeout: 120)
    stats_elapsed = (Time.current - stats_start).round(2)
    Rails.logger.info "[ResourceMetrics] #{server.name}:   Done in #{stats_elapsed}s (#{stats_out.lines.count} lines, exit: #{_code})"
    if stats_err.present? || _code != 0
      Rails.logger.warn "[ResourceMetrics] #{server.name}:   Warning: #{stats_err}"
    end
    
    # Parse bulk stats into lookup map by container name
    stats_by_name = {}
    stats_out.each_line do |line|
      line = line.strip
      next if line.empty?
      data = JSON.parse(line) rescue nil
      if data && data['Name']
        stats_by_name[data['Name']] = data
      end
    end
    Rails.logger.info "[ResourceMetrics] #{server.name}:   Parsed #{stats_by_name.count} stat entries"
    
    # 2. Get ALL container inspect data at once (~3s for 392 containers)
    Rails.logger.info "[ResourceMetrics] #{server.name}: → Fetching docker inspect (bulk)..."
    inspect_start = Time.current
    container_ids = id_to_resource.keys.join(' ')
    _code, inspect_out, _ = client.exec!("docker inspect --size #{container_ids}", timeout: 60)
    inspect_elapsed = (Time.current - inspect_start).round(2)
    Rails.logger.info "[ResourceMetrics] #{server.name}:   Done in #{inspect_elapsed}s"
    
    # Parse bulk inspect into lookup map by container ID
    inspect_data_all = JSON.parse(inspect_out) rescue []
    inspect_by_id = {}
    inspect_data_all.each { |d| inspect_by_id[d['Id']] = d }
    
    # 3. Collect all unique volume paths for bulk size calculation
    Rails.logger.info "[ResourceMetrics] #{server.name}: → Collecting volume paths..."
    volume_paths = []
    path_to_container_ids = {} # Map path -> list of container IDs using it
    
    inspect_data_all.each do |inspect_data|
      container_id = inspect_data['Id']
      mounts = inspect_data['Mounts'] || []
      
      mounts.each do |mount|
        source = mount['Source']
        next unless source.present?
        
        unless volume_paths.include?(source)
          volume_paths << source
        end
        
        path_to_container_ids[source] ||= []
        path_to_container_ids[source] << container_id
      end
    end
    
    Rails.logger.info "[ResourceMetrics] #{server.name}:   Found #{volume_paths.count} unique volume paths"
    
    # 4. Bulk calculate all volume sizes (simple du approach)
    volume_sizes = {}
    if volume_paths.any?
      Rails.logger.info "[ResourceMetrics] #{server.name}: → Calculating volume sizes (#{volume_paths.count} paths)..."
      du_start = Time.current
      
      begin
        # Use simple du -sb for all paths
        # Note: this can be slow for very large volumes, but SSH timeout will catch it
        escaped_paths = volume_paths.map { |p| p.shellescape }.join(' ')
        _code, du_out, du_err = client.exec!(
          "du -sb #{escaped_paths} 2>/dev/null",
          timeout: 45
        )
        
        du_elapsed = (Time.current - du_start).round(2)
        
        # Parse output: "size\tpath"
        du_out.each_line do |line|
          parts = line.strip.split("\t", 2)
          next unless parts.length == 2
          
          size_bytes = parts[0].to_i
          path = parts[1]
          volume_sizes[path] = size_bytes if size_bytes > 0
        end
        
        if volume_sizes.any?
          total_gb = (volume_sizes.values.sum.to_f / 1024 / 1024 / 1024).round(2)
          Rails.logger.info "[ResourceMetrics] #{server.name}:   Calculated #{volume_sizes.count}/#{volume_paths.count} volumes (#{total_gb}GB total) in #{du_elapsed}s"
        else
          Rails.logger.warn "[ResourceMetrics] #{server.name}:   No volume sizes calculated - continuing without volumes"
        end
      rescue => e
        du_elapsed = (Time.current - du_start).round(2)
        Rails.logger.warn "[ResourceMetrics] #{server.name}:   Volume calculation failed after #{du_elapsed}s (#{e.message}) - continuing without volumes"
        volume_sizes = {}
      end
    end
    
    # 3. Process all containers using pre-fetched bulk data
    Rails.logger.info "[ResourceMetrics] #{server.name}: → Processing #{total} containers with bulk data..."
    collected = 0
    missing_stats = 0
    
    id_to_resource.each do |(cid, resource)|
      # Get container name for stats lookup
      container_data = containers.find { |c| c['Id'] == cid }
      container_name = container_data&.dig('Names')&.first&.sub(/^\//, '')
      
      # Extract stats from bulk data
      stats_data = stats_by_name[container_name]
      if stats_data.nil? && collected < 3
        Rails.logger.warn "[ResourceMetrics] #{server.name}:   Missing stats for: #{container_name} (#{resource.name})"
        missing_stats += 1
      end
      cpu_pct, mem_pct, mem_used, mem_limit = parse_docker_stats(stats_data)
      
      # Extract inspect data from bulk data
      inspect_data = inspect_by_id[cid]
      size_rw = inspect_data&.dig('SizeRw').to_i
      
      # Calculate total volume size for this container
      container_volume_size = 0
      mounts = inspect_data&.dig('Mounts') || []
      mounts.each do |mount|
        source = mount['Source']
        container_volume_size += volume_sizes[source].to_i if source.present?
      end
      
      # Get memory limit from container config (0 means no limit)
      container_mem_limit = inspect_data&.dig('HostConfig', 'Memory').to_i
      # Use container limit if set, otherwise use system memory from stats
      final_mem_limit = container_mem_limit > 0 ? container_mem_limit : mem_limit
      
      # Log detailed info for first few containers
      if collected < 3
        limit_source = container_mem_limit > 0 ? "container limit" : "system memory"
        limit_gb = (final_mem_limit.to_f / 1024 / 1024 / 1024).round(2)
        used_mb = (mem_used.to_f / 1024 / 1024).round(1)
        
        rw_mb = (size_rw.to_f / 1024 / 1024).round(1)
        vol_mb = (container_volume_size.to_f / 1024 / 1024).round(1)
        
        Rails.logger.info "[ResourceMetrics] #{server.name}:   #{resource.name}:"
        Rails.logger.info "[ResourceMetrics] #{server.name}:     MEM: #{used_mb}MB / #{limit_gb}GB (#{limit_source})"
        Rails.logger.info "[ResourceMetrics] #{server.name}:     DISK: RW=#{rw_mb}MB, Volumes=#{vol_mb}MB (#{mounts.count} mounts)"
      end
      
      ResourceStat.create!(
        resource: resource,
        server: server,
        captured_at: now,
        cpu_pct: cpu_pct,
        mem_pct: mem_pct,
        mem_used_bytes: mem_used,
        mem_limit_bytes: final_mem_limit,
        disk_runtime_bytes: size_rw,
        disk_persistent_bytes: container_volume_size
      )
      collected += 1
      
      if collected % 50 == 0
        Rails.logger.info "[ResourceMetrics] #{server.name}:   Progress: #{collected}/#{total} (#{missing_stats} missing stats)"
      end
    end
    
    if missing_stats > 0
      Rails.logger.warn "[ResourceMetrics] #{server.name}:   Total containers with missing stats: #{missing_stats}/#{total}"
    end
    
    elapsed = (Time.current - start_time).round(1)
    Rails.logger.info "[ResourceMetrics] #{server.name}: ✓ Collected #{collected} stats in #{elapsed}s"
  rescue => e
    elapsed = (Time.current - start_time).round(1) rescue 0
    Rails.logger.error "[ResourceMetrics] #{server.name}: ✗ FAILED after #{elapsed}s - #{e.class}: #{e.message}"
  end

  private

  # Parse docker stats JSON format output (from bulk docker stats command)
  def parse_docker_stats(stats_data)
    return [nil, nil, nil, nil] unless stats_data
    
    # docker stats --format json gives us: CPUPerc, MemPerc, MemUsage
    # Format: "12.34%" or "123.4MiB / 15.6GiB"
    cpu_str = stats_data['CPUPerc']
    cpu_pct = cpu_str.to_f if cpu_str
    
    mem_usage_str = stats_data['MemUsage'] # e.g., "123.4MiB / 15.6GiB"
    mem_perc_str = stats_data['MemPerc']
    mem_pct = mem_perc_str.to_f if mem_perc_str
    
    # Parse memory usage and limit (convert to bytes)
    if mem_usage_str
      parts = mem_usage_str.split('/')
      mem_used = parse_size_to_bytes(parts[0]&.strip)
      mem_limit = parse_size_to_bytes(parts[1]&.strip)  # System/container memory limit
    end
    
    [cpu_pct, mem_pct, mem_used, mem_limit]
  rescue
    [nil, nil, nil, nil]
  end
  
  # Convert docker size strings like "123.4MiB" to bytes
  def parse_size_to_bytes(size_str)
    return nil unless size_str
    
    # Match number and unit
    match = size_str.match(/^([\d.]+)\s*([KMGTP]i?B?)$/i)
    return nil unless match
    
    value = match[1].to_f
    unit = match[2].upcase
    
    # Convert to bytes
    case unit
    when 'B' then value
    when 'KB', 'KIB' then value * 1024
    when 'MB', 'MIB' then value * 1024 * 1024
    when 'GB', 'GIB' then value * 1024 * 1024 * 1024
    when 'TB', 'TIB' then value * 1024 * 1024 * 1024 * 1024
    when 'PB', 'PIB' then value * 1024 * 1024 * 1024 * 1024 * 1024
    else value
    end.to_i
  end
end


