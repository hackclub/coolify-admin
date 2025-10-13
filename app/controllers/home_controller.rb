class HomeController < ApplicationController
  def index
    @teams_data = CoolifyTeam.all.map do |team|
      begin
        Rails.logger.info "🔍 Connecting to #{team.name} at #{team.base_url}"
        api = Coolify.for(team)
        api.ensure_prefix!
        Rails.logger.info "✅ Prefix detected for #{team.name}"
        servers = api.servers
        Rails.logger.info "✅ Got #{servers.length} servers for #{team.name}"
        { team: team, servers: servers, error: nil }
      rescue Coolify::ConnectionError => e
        Rails.logger.error "❌ ConnectionError for #{team.name}: #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        { team: team, servers: [], error: "Connection failed: #{e.message}" }
      rescue Coolify::UnauthorizedError => e
        Rails.logger.error "❌ UnauthorizedError for #{team.name}: #{e.message}"
        { team: team, servers: [], error: "Authentication failed: Invalid API token" }
      rescue Coolify::ApiError => e
        Rails.logger.error "❌ ApiError for #{team.name}: #{e.message}"
        { team: team, servers: [], error: "API error: #{e.message}" }
      rescue StandardError => e
        Rails.logger.error "❌ StandardError for #{team.name}: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        { team: team, servers: [], error: "Error: #{e.message}" }
      end
    end
  end
end

