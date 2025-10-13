# frozen_string_literal: true

class CoolifySyncService
  class SyncError < StandardError; end

  def self.sync_all
    new.sync_all
  end

  def sync_all
    results = {}
    
    CoolifyTeam.find_each do |coolify_team|
      results[coolify_team.name] = sync_team(coolify_team)
    end

    {
      success: results.values.all? { |r| r[:success] },
      teams: results
    }
  end

  def sync_team(coolify_team)
    Rails.logger.info "🔄 Starting sync for #{coolify_team.name}"
    
    # Phase 1: Fetch all data from API (fail fast if API errors)
    api_data = fetch_api_data(coolify_team)
    
    # Phase 2: Delete and replace in transaction
    counts = replace_data(coolify_team, api_data)
    
    Rails.logger.info "✅ Sync completed for #{coolify_team.name}: #{counts.inspect}"
    
    {
      success: true,
      synced: counts
    }
  rescue Coolify::Error => e
    Rails.logger.error "❌ API error for #{coolify_team.name}: #{e.message}"
    {
      success: false,
      error: "API error: #{e.message}"
    }
  rescue StandardError => e
    Rails.logger.error "❌ Sync error for #{coolify_team.name}: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    {
      success: false,
      error: "#{e.class}: #{e.message}"
    }
  end

  private

  def fetch_environments_in_batches(api, projects_data, batch_size: 10)
    projects_with_envs = []
    total_batches = (projects_data.length.to_f / batch_size).ceil
    
    projects_data.each_slice(batch_size).with_index do |batch, batch_index|
      # Add delay between batches to avoid rate limiting (2 seconds between batches)
      sleep(2) if batch_index > 0
      
      Rails.logger.info "    Batch #{batch_index + 1}/#{total_batches} (projects #{batch_index * batch_size + 1}-#{[batch_index * batch_size + batch.length, projects_data.length].min})"
      
      # Fetch environments for this batch
      batch.each do |project|
        begin
          envs = api.environments(project['uuid'])
          projects_with_envs << project.merge('environments' => envs)
        rescue Coolify::ApiError => e
          if e.message.include?('429') || e.message.include?('Too Many Attempts')
            Rails.logger.warn "      ⏳ Rate limited, waiting 5 seconds..."
            sleep(5)
            # Retry once
            begin
              envs = api.environments(project['uuid'])
              projects_with_envs << project.merge('environments' => envs)
            rescue => retry_error
              Rails.logger.error "      ❌ Retry failed for project #{project['name']}: #{retry_error.message}"
              projects_with_envs << project.merge('environments' => [])
            end
          else
            # If not a rate limit error, skip this project and log
            Rails.logger.error "      ❌ Failed for project #{project['name']}: #{e.message}"
            projects_with_envs << project.merge('environments' => [])
          end
        end
      end
    end
    
    projects_with_envs
  end

  def fetch_api_data(coolify_team)
    api = Coolify.for(coolify_team)
    
    Rails.logger.info "  📡 Fetching team data..."
    team_data = api.current_team

    Rails.logger.info "  📡 Fetching servers (with key metadata)..."
    begin
      tree = api.tree
      servers_data = tree["servers"] || []
    rescue => e
      Rails.logger.warn "  ⚠️ Tree fetch failed (#{e.message}), falling back to /servers"
      servers_data = api.servers
    end

    Rails.logger.info "  📡 Fetching projects..."
    projects_data = api.projects

    # Fetch environments for projects (required for resource sync)
    Rails.logger.info "  📡 Fetching environments for #{projects_data.length} projects (batched)..."
    projects_with_envs = fetch_environments_in_batches(api, projects_data)

    Rails.logger.info "  📡 Fetching applications..."
    applications_data = api.applications

    Rails.logger.info "  📡 Fetching services..."
    services_data = api.services

    Rails.logger.info "  📡 Fetching databases..."
    databases_data = api.databases

    {
      team: team_data,
      servers: servers_data,
      projects: projects_with_envs,
      applications: applications_data,
      services: services_data,
      databases: databases_data
    }
  end

  def replace_data(coolify_team, api_data)
    counts = {
      teams: 0,
      servers: 0,
      projects: 0,
      environments: 0,
      applications: 0,
      services: 0,
      databases: 0
    }

    ActiveRecord::Base.transaction do
      Rails.logger.info "  🗑️  Deleting old data..."
      
      # Delete all existing data (cascade via dependent: :destroy)
      old_teams_count = coolify_team.teams.count
      old_servers_count = coolify_team.servers.count
      old_projects_count = coolify_team.projects.count
      old_resources_count = coolify_team.resources.count
      
      Rails.logger.info "    Deleting #{old_teams_count} teams..."
      coolify_team.teams.destroy_all
      
      Rails.logger.info "    Deleting #{old_servers_count} servers..."
      coolify_team.servers.destroy_all
      
      Rails.logger.info "    Deleting #{old_projects_count} projects (and cascading environments/resources)..."
      coolify_team.projects.destroy_all
      
      Rails.logger.info "    ✅ Deleted #{old_teams_count} teams, #{old_servers_count} servers, #{old_projects_count} projects, #{old_resources_count} resources"

      Rails.logger.info "  ✨ Creating fresh data..."

      # Create team
      if api_data[:team]
        Rails.logger.info "    Creating team: #{api_data[:team]['name']}..."
        create_team(coolify_team, api_data[:team])
        counts[:teams] = 1
      end

      # Create servers
      Rails.logger.info "    Creating #{api_data[:servers].length} servers..."
      api_data[:servers].each_with_index do |server_data, index|
        create_server(coolify_team, server_data)
        counts[:servers] += 1
        Rails.logger.info "      ✓ Server #{index + 1}/#{api_data[:servers].length}: #{server_data['name']}" if (index + 1) % 10 == 0 || index == api_data[:servers].length - 1
      end

      # Create projects
      Rails.logger.info "    Creating #{api_data[:projects].length} projects..."
      api_data[:projects].each_with_index do |project_data, index|
        project = create_project(coolify_team, project_data)
        counts[:projects] += 1

        # Create environments for this project (if any were fetched)
        if project_data['environments'] && project_data['environments'].any?
          project_data['environments'].each do |env_data|
            create_environment(project, env_data)
            counts[:environments] += 1
          end
        end
        
        Rails.logger.info "      ✓ Project #{index + 1}/#{api_data[:projects].length}: #{project_data['name']}" if (index + 1) % 50 == 0 || index == api_data[:projects].length - 1
      end

      # Extract and update server IDs before creating resources
      # (Services need server IDs to match, but /servers endpoint doesn't provide them)
      Rails.logger.info "    Updating server IDs from resource destinations..."
      update_server_ids(coolify_team, api_data[:applications], api_data[:databases])
      
      # Create resources (applications, services, databases)
      Rails.logger.info "    Creating #{api_data[:applications].length} applications..."
      api_data[:applications].each_with_index do |app_data, index|
        result = create_application(coolify_team, app_data)
        counts[:applications] += 1 if result
        counts[:environments] += 1 if result && result[:created_environment]
        Rails.logger.info "      ✓ App #{index + 1}/#{api_data[:applications].length}: #{app_data['name']}" if (index + 1) % 20 == 0 || index == api_data[:applications].length - 1
      end

      Rails.logger.info "    Creating #{api_data[:services].length} services..."
      api_data[:services].each_with_index do |service_data, index|
        result = create_service(coolify_team, service_data)
        counts[:services] += 1 if result
        counts[:environments] += 1 if result && result[:created_environment]
        Rails.logger.info "      ✓ Service #{index + 1}/#{api_data[:services].length}: #{service_data['name']}" if (index + 1) % 20 == 0 || index == api_data[:services].length - 1
      end

      Rails.logger.info "    Creating #{api_data[:databases].length} databases..."
      api_data[:databases].each_with_index do |db_data, index|
        result = create_database(coolify_team, db_data)
        counts[:databases] += 1 if result
        counts[:environments] += 1 if result && result[:created_environment]
        Rails.logger.info "      ✓ Database #{index + 1}/#{api_data[:databases].length}: #{db_data['name']}" if (index + 1) % 20 == 0 || index == api_data[:databases].length - 1
      end
      
      Rails.logger.info "  ✅ Transaction complete!"
    end

    Rails.logger.info "  📊 Final counts: #{counts.inspect}"
    counts
  end

  # Create methods for each model
  def create_team(coolify_team, data)
    Team.create!(
      coolify_team: coolify_team,
      team_id: data['id'],
      name: data['name'],
      description: data['description'],
      personal_team: data['personal_team'] || false,
      metadata: data
    )
  end

  def create_server(coolify_team, data)
    # Note: The /servers endpoint doesn't return the internal 'id' field
    # We'll add it later from application/database destination data
    server = Server.create!(
      coolify_team: coolify_team,
      uuid: data['uuid'],
      name: data['name'],
      description: data['description'],
      ip: data['ip'],
      port: data['port'],
      user: data['user'],
      proxy_type: data['proxy_type'],
      is_reachable: data.dig('settings', 'is_reachable') || false,
      metadata: data
    )

    # Create/update PrivateKey stub if API provides private_key_id/name
    key_uuid = data['private_key_id'] || data.dig('private_key', 'uuid')
    key_name = data.dig('private_key', 'name')
    if key_uuid.present?
      pk = PrivateKey.find_or_initialize_by(coolify_team: coolify_team, uuid: key_uuid)
      pk.name ||= key_name || "Key #{key_uuid}"
      pk.source = 'manual'
      pk.save!
      server.update!(private_key: pk)
    end

    server
  end
  
  def update_server_ids(coolify_team, applications_data, databases_data)
    # Extract server IDs from application/database destinations
    # (The /servers endpoint doesn't include the internal id field)
    server_ids = {}
    
    [applications_data, databases_data].flatten.each do |resource|
      next unless resource && resource['destination'] && resource['destination']['server']
      
      uuid = resource['destination']['server']['uuid']
      id = resource['destination']['server']['id']
      server_ids[uuid] = id if uuid && id
    end
    
    # Update our servers with the extracted IDs
    server_ids.each do |uuid, id|
      server = coolify_team.servers.find_by(uuid: uuid)
      if server && !server.metadata['id']
        server.metadata['id'] = id
        server.save!
        Rails.logger.info "      🔗 Added id #{id} to server #{server.name}"
      end
    end
  end

  def create_project(coolify_team, data)
    Project.create!(
      coolify_team: coolify_team,
      uuid: data['uuid'],
      name: data['name'],
      description: data['description'],
      metadata: data.except('environments')
    )
  end

  def create_environment(project, data)
    Environment.create!(
      project: project,
      environment_id: data['id'],
      name: data['name'],
      description: data['description'],
      metadata: data
    )
  end

  def create_application(coolify_team, data)
    # Find server and environment
    server = coolify_team.servers.find_by(uuid: data['destination']['server']['uuid']) if data['destination']&.dig('server', 'uuid')
    
    unless server
      Rails.logger.warn "      ⚠️  Skipping application #{data['name']} - server not found"
      return nil
    end
    
    env_result = find_or_create_environment(coolify_team, data['environment_id'], data['environment']) if data['environment_id']
    environment = env_result[:environment] if env_result
    
    unless environment
      Rails.logger.warn "      ⚠️  Skipping application #{data['name']} - environment not found/created"
      return nil
    end

    Application.create!(
      coolify_team: coolify_team,
      server: server,
      environment: environment,
      uuid: data['uuid'],
      name: data['name'],
      description: data['description'],
      status: data['status'],
      fqdn: data['fqdn'],
      metadata: extract_application_metadata(data)
    )
    
    { created_environment: env_result[:created] }
  end

  def create_service(coolify_team, data)
    # Services have server_id directly (not nested in destination like apps/databases)
    # Find server by Coolify's internal server_id stored in metadata
    server = nil
    if data['server_id']
      # Use SQL query to find server by metadata id (works within transaction)
      server = coolify_team.servers.where("metadata->>'id' = ?", data['server_id'].to_s).first
    end
    # Fallback: try destination structure if it exists
    server ||= coolify_team.servers.find_by(uuid: data['destination']['server']['uuid']) if data['destination']&.dig('server', 'uuid')
    
    unless server
      Rails.logger.warn "      ⚠️  Skipping service #{data['name']} - server not found (server_id: #{data['server_id']})"
      return nil
    end
    
    env_result = find_or_create_environment(coolify_team, data['environment_id'], data['environment']) if data['environment_id']
    environment = env_result[:environment] if env_result
    
    unless environment
      Rails.logger.warn "      ⚠️  Skipping service #{data['name']} - environment not found/created"
      return nil
    end

    Service.create!(
      coolify_team: coolify_team,
      server: server,
      environment: environment,
      uuid: data['uuid'],
      name: data['name'],
      description: data['description'],
      status: data['status'],
      fqdn: nil,  # Services typically don't have a single FQDN
      metadata: extract_service_metadata(data)
    )
    
    { created_environment: env_result[:created] }
  end

  def create_database(coolify_team, data)
    # Find server and environment
    server = coolify_team.servers.find_by(uuid: data['destination']['server']['uuid']) if data['destination']&.dig('server', 'uuid')
    
    unless server
      Rails.logger.warn "      ⚠️  Skipping database #{data['name']} - server not found"
      return nil
    end
    
    env_result = find_or_create_environment(coolify_team, data['environment_id'], data['environment']) if data['environment_id']
    environment = env_result[:environment] if env_result
    
    unless environment
      Rails.logger.warn "      ⚠️  Skipping database #{data['name']} - environment not found/created"
      return nil
    end

    CoolifyDatabase.create!(
      coolify_team: coolify_team,
      server: server,
      environment: environment,
      uuid: data['uuid'],
      name: data['name'],
      description: data['description'],
      status: data['status'],
      fqdn: nil,  # Databases typically don't have FQDN unless public
      metadata: extract_database_metadata(data)
    )
    
    { created_environment: env_result[:created] }
  end

  # Helper to find or create environment by Coolify's environment_id
  def find_or_create_environment(coolify_team, environment_id, environment_data)
    # Try to find existing environment
    env = coolify_team.projects.joins(:environments).find_by(environments: { environment_id: environment_id })&.environments&.find_by(environment_id: environment_id)
    return { environment: env, created: false } if env

    # Environment doesn't exist
    # If we have environment_data with project info, use it
    if environment_data && environment_data['project']
      project = coolify_team.projects.find_by(uuid: environment_data['project']['uuid'])
      
      if project
        new_env = Environment.create!(
          project: project,
          environment_id: environment_id,
          name: environment_data['name'] || "Environment #{environment_id}",
          description: environment_data['description'],
          metadata: environment_data
        )
        Rails.logger.info "        ➕ Created environment #{environment_id}: #{new_env.name}"
        return { environment: new_env, created: true }
      end
    end
    
    # If we don't have environment data, we can't create it without knowing which project it belongs to
    # This happens when syncing resources without fetching environments first
    # We'll skip this resource and log a warning
    Rails.logger.debug "        ⚠️  Cannot create environment #{environment_id} - no project info available"
    nil
  end

  # Extract relevant metadata for each resource type
  def extract_application_metadata(data)
    {
      'git_repository' => data['git_repository'],
      'git_branch' => data['git_branch'],
      'git_commit_sha' => data['git_commit_sha'],
      'build_pack' => data['build_pack'],
      'docker_registry_image_name' => data['docker_registry_image_name'],
      'docker_registry_image_tag' => data['docker_registry_image_tag'],
      'docker_compose_raw' => data['docker_compose_raw'],
      'ports_exposes' => data['ports_exposes'],
      'raw' => data
    }.compact
  end

  def extract_service_metadata(data)
    {
      'service_type' => data['service_type'],
      'docker_compose_raw' => data['docker_compose_raw'],
      'raw' => data
    }.compact
  end

  def extract_database_metadata(data)
    {
      'database_type' => detect_database_type(data),
      'image' => data['image'],
      'is_public' => data['is_public'],
      'public_port' => data['public_port'],
      'raw' => data
    }.compact
  end

  def detect_database_type(data)
    # Try to detect from the data structure or type field
    data['type'] || data['database_type'] || 'unknown'
  end
end

