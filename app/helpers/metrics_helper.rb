module MetricsHelper
  def format_bytes(bytes)
    return 'N/A' unless bytes
    units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB']
    size = bytes.to_f
    unit_index = 0
    while size >= 1024 && unit_index < units.length - 1
      size /= 1024.0
      unit_index += 1
    end
    "#{size.round(1)}#{units[unit_index]}"
  end

  def format_memory_stat(stat)
    return 'N/A' unless stat&.mem_used_bytes
    
    # Use stored memory limit if available (only ResourceStat has this field)
    if stat.respond_to?(:mem_limit_bytes) && stat.mem_limit_bytes && stat.mem_limit_bytes > 0
      total = stat.mem_limit_bytes
      pct = stat.mem_pct || ((stat.mem_used_bytes.to_f / total) * 100).round(1)
    elsif stat.mem_pct
      total = (stat.mem_used_bytes / (stat.mem_pct / 100.0)).round
      pct = stat.mem_pct.round(1)
    else
      return "#{format_bytes(stat.mem_used_bytes)}"
    end
    
    "#{format_bytes(stat.mem_used_bytes)}/#{format_bytes(total)} (#{pct.round(1)}%)"
  end

  def format_disk_stat(stat)
    return 'N/A' unless stat&.disk_used_bytes && stat&.disk_total_bytes
    pct = ((stat.disk_used_bytes.to_f / stat.disk_total_bytes) * 100).round(1)
    "#{format_bytes(stat.disk_used_bytes)}/#{format_bytes(stat.disk_total_bytes)} (#{pct}%)"
  end

  def format_load_stat(stat, server)
    return 'N/A' unless stat&.load1
    cores = server.cpu_cores || 1
    load_pct = ((stat.load1 / cores) * 100).round(0)
    "#{stat.load1.round(2)} (#{load_pct}% of #{cores} cores)"
  end

  def local_filesystems(stat)
    return [] unless stat&.filesystems
    stat.filesystems.select do |fs|
      # Exclude remote/network filesystems
      fstype = fs['fstype'].to_s
      device = fs['device'].to_s
      !fstype.start_with?('fuse') && !['nfs', 'cifs', 'smbfs'].include?(fstype) && !device.include?(':')
    end
  end

  def format_filesystem(fs)
    used = format_bytes(fs['used_bytes'])
    total = format_bytes(fs['total_bytes'])
    pct = ((fs['used_bytes'].to_f / fs['total_bytes']) * 100).round(1) rescue 0
    mount = fs['mountpoint'].gsub('/mnt/', '')
    "#{mount}: #{used}/#{total} (#{pct}%)"
  end
end
