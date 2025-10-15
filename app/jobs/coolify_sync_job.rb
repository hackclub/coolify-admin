class CoolifySyncJob < ApplicationJob
  queue_as :default

  def perform(coolify_team_id = nil)
    if coolify_team_id
      # Sync a specific team
      coolify_team = CoolifyTeam.find(coolify_team_id)
      CoolifySyncService.new.sync_team(coolify_team)
    else
      # Sync all teams
      CoolifySyncService.sync_all
    end
  end
end

