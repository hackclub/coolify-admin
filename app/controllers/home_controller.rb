class HomeController < ApplicationController
  def index
    @teams_data = CoolifyTeam.all.map do |team|
      begin
        Rails.logger.info "🔍 Fetching tree for #{team.name} at #{team.base_url}"
        api = Coolify.for(team)
        tree = api.tree
        Rails.logger.info "✅ Got tree data for #{team.name}"
        { team: team, tree: tree, error: nil }
      rescue Coolify::ConnectionError => e
        Rails.logger.error "❌ ConnectionError for #{team.name}: #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        { team: team, tree: {}, error: "Connection failed: #{e.message}" }
      rescue Coolify::UnauthorizedError => e
        Rails.logger.error "❌ UnauthorizedError for #{team.name}: #{e.message}"
        { team: team, tree: {}, error: "Authentication failed: Invalid API token" }
      rescue Coolify::ApiError => e
        Rails.logger.error "❌ ApiError for #{team.name}: #{e.message}"
        { team: team, tree: {}, error: "API error: #{e.message}" }
      rescue StandardError => e
        Rails.logger.error "❌ StandardError for #{team.name}: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        { team: team, tree: {}, error: "Error: #{e.message}" }
      end
    end
  end
end

