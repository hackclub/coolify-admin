class HomeController < ApplicationController
  def index
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
  end
end

