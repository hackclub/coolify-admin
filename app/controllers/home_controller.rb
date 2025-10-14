class HomeController < ApplicationController
  def index
    @view = params[:view] || 'tree'
    @server_id = params[:server_id]
    
    # Fetch all CoolifyTeams with their synced data
    @coolify_teams = CoolifyTeam.includes(
      :teams,
      :servers,
      projects: { environments: :resources }
    ).all
    
    # Build summary stats
    @stats = {
      teams: Team.count,
      servers: Server.count,
      projects: Project.count,
      environments: Environment.count,
      applications: Application.count,
      services: Service.count,
      databases: CoolifyDatabase.count,
      total_resources: Resource.count
    }
    
    # Preload latest stats per server/resource for display
    @latest_server_stats = ServerStat
      .where(id: ServerStat.select('DISTINCT ON (server_id) id').order('server_id, captured_at DESC'))
      .index_by(&:server_id)

    @latest_resource_stats = ResourceStat
      .where(id: ResourceStat.select('DISTINCT ON (resource_id) id').order('resource_id, captured_at DESC'))
      .index_by(&:resource_id)
    
    # Prepare data based on view
    case @view
    when 'storage'
      prepare_storage_view
    when 'cpu'
      prepare_cpu_view
    when 'ram'
      prepare_ram_view
    end
    
    # Get all servers for filter dropdown
    @servers = Server.order(:name)
  end
  
  private
  
  def prepare_storage_view
    # Get all resources with their latest stats
    query = Resource.includes(:server, environment: :project)
    
    # Filter by server if specified
    query = query.where(server_id: @server_id) if @server_id.present?
    
    # Join with latest resource stats and calculate total disk usage
    @resources_by_storage = query
      .left_joins(:resource_stats)
      .select('resources.*, 
               MAX(resource_stats.created_at) as latest_stat_time,
               MAX(COALESCE(resource_stats.disk_runtime_bytes, 0) + COALESCE(resource_stats.disk_persistent_bytes, 0)) as total_disk_bytes')
      .group('resources.id')
      .order('total_disk_bytes DESC NULLS LAST')
      .limit(100)
  end
  
  def prepare_cpu_view
    # Get all resources with their latest stats
    query = Resource.includes(:server, environment: :project)
    
    # Filter by server if specified
    query = query.where(server_id: @server_id) if @server_id.present?
    
    # Join with latest resource stats and order by CPU usage
    @resources_by_cpu = query
      .left_joins(:resource_stats)
      .select('resources.*, 
               MAX(resource_stats.created_at) as latest_stat_time,
               MAX(resource_stats.cpu_pct) as max_cpu_pct')
      .group('resources.id')
      .order('max_cpu_pct DESC NULLS LAST')
      .limit(100)
  end
  
  def prepare_ram_view
    # Get all resources with their latest stats
    query = Resource.includes(:server, environment: :project)
    
    # Filter by server if specified
    query = query.where(server_id: @server_id) if @server_id.present?
    
    # Join with latest resource stats and order by memory usage
    @resources_by_ram = query
      .left_joins(:resource_stats)
      .select('resources.*, 
               MAX(resource_stats.created_at) as latest_stat_time,
               MAX(resource_stats.mem_used_bytes) as max_mem_used')
      .group('resources.id')
      .order('max_mem_used DESC NULLS LAST')
      .limit(100)
  end
end

