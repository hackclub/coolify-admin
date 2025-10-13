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
  end
end

