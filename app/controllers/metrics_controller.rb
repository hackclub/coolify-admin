class MetricsController < ApplicationController
  protect_from_forgery with: :null_session

  def collect_now
    # Trigger server and resource collectors for all reachable servers
    servers = Server.reachable
    triggered = 0
    skipped = []

    servers.find_each do |s|
      if s.private_key&.private_key.present?
        ServerMetricsCollectorJob.perform_later(s.id)
        ResourceMetricsCollectorJob.perform_later(s.id)
        triggered += 1
      else
        skipped << s.name
      end
    end

    render json: { success: true, triggered: triggered, skipped: skipped }
  rescue => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def ssh_test
    server = Server.find(params[:id])
    key = server.private_key&.private_key
    return render json: { success: false, error: 'No key' }, status: :unprocessable_entity unless key.present?

    client = SshClient.new(host: server.ip, user: server.user, port: server.port || 22, private_key: key)
    code, out, err = client.exec!("echo ok && whoami && uname -a", timeout: 6)
    render json: { success: true, exit: code, stdout: out, stderr: err }
  rescue => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def collect_server_stats
    server = Server.find(params[:id])
    
    unless server.private_key&.private_key.present?
      return render json: { success: false, error: 'No SSH key configured' }, status: :unprocessable_entity
    end
    
    # Run jobs synchronously in background thread so request doesn't timeout
    Thread.new do
      begin
        Rails.logger.info "[ManualTrigger] Starting collection for server #{server.id} (#{server.name})"
        ServerMetricsCollectorJob.perform_now(server.id)
        ResourceMetricsCollectorJob.perform_now(server.id)
        Rails.logger.info "[ManualTrigger] Completed collection for server #{server.id}"
      rescue => e
        Rails.logger.error "[ManualTrigger] Failed for server #{server.id}: #{e.message}"
      end
    end
    
    # Count resources that will be collected
    resources_count = server.resources.count
    
    render json: { 
      success: true, 
      server_id: server.id,
      server_name: server.name,
      resources_triggered: resources_count
    }
  rescue => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end
end


