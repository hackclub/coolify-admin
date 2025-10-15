class CollectAllMetricsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[CollectAllMetrics] Starting metrics collection for all servers..."
    
    servers = Server.reachable
    triggered = 0
    skipped = []

    servers.find_each do |server|
      if server.private_key&.private_key.present?
        ServerMetricsCollectorJob.perform_later(server.id)
        ResourceMetricsCollectorJob.perform_later(server.id)
        triggered += 1
      else
        skipped << server.name
        Rails.logger.warn "[CollectAllMetrics] Skipped #{server.name}: No SSH key configured"
      end
    end

    Rails.logger.info "[CollectAllMetrics] ✓ Triggered metrics collection for #{triggered} servers"
    Rails.logger.info "[CollectAllMetrics] Skipped #{skipped.length} servers: #{skipped.join(', ')}" if skipped.any?
    
    { triggered: triggered, skipped: skipped }
  end
end

