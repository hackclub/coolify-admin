class ServersController < ApplicationController
  def show
    @server = Server.includes(:coolify_team, :private_key).find(params[:id])
    
    # Get time range for stats (default: last 24 hours)
    @time_range = params[:time_range] || '24h'
    @since = case @time_range
             when '1h' then 1.hour.ago
             when '6h' then 6.hours.ago
             when '24h' then 24.hours.ago
             when '7d' then 7.days.ago
             when '30d' then 30.days.ago
             else 24.hours.ago
             end
    
    # Get stats for charts (ordered by time)
    @stats = @server.server_stats
                    .where('captured_at >= ?', @since)
                    .order(captured_at: :asc)
    
    # Get latest stat
    @latest_stat = @server.server_stats.order(captured_at: :desc).first
    
    # Prepare chart data
    @chart_data = prepare_chart_data(@stats)
    
    # Get latest stats for summary
    @stats_summary = calculate_stats_summary(@stats)
    
    # Get resources count
    @resources_count = @server.resources.count
  end
  
  private
  
  def prepare_chart_data(stats)
    {
      timestamps: stats.map { |s| s.captured_at.to_i * 1000 }, # milliseconds for Chart.js
      cpu: stats.map { |s| s.cpu_pct&.round(2) },
      memory_pct: stats.map { |s| s.mem_pct&.round(2) },
      memory_bytes: stats.map { |s| s.mem_used_bytes },
      disk_used: stats.map { |s| s.disk_used_bytes },
      disk_total: stats.map { |s| s.disk_total_bytes },
      iops_read: stats.map { |s| s.iops_r&.round(2) },
      iops_write: stats.map { |s| s.iops_w&.round(2) },
      load1: stats.map { |s| s.load1&.round(2) },
      load5: stats.map { |s| s.load5&.round(2) },
      load15: stats.map { |s| s.load15&.round(2) }
    }
  end
  
  def calculate_stats_summary(stats)
    return {} if stats.empty?
    
    cpu_values = stats.map(&:cpu_pct).compact
    mem_values = stats.map(&:mem_used_bytes).compact
    disk_used_values = stats.map(&:disk_used_bytes).compact
    disk_total_values = stats.map(&:disk_total_bytes).compact
    iops_r_values = stats.map(&:iops_r).compact
    iops_w_values = stats.map(&:iops_w).compact
    load1_values = stats.map(&:load1).compact
    load5_values = stats.map(&:load5).compact
    load15_values = stats.map(&:load15).compact
    
    {
      cpu_avg: cpu_values.any? ? (cpu_values.sum / cpu_values.size).round(2) : nil,
      cpu_max: cpu_values.max,
      cpu_min: cpu_values.min,
      mem_avg: mem_values.any? ? (mem_values.sum / mem_values.size).round(0) : nil,
      mem_max: mem_values.max,
      mem_min: mem_values.min,
      disk_used_avg: disk_used_values.any? ? (disk_used_values.sum / disk_used_values.size).round(0) : nil,
      disk_used_max: disk_used_values.max,
      disk_total_avg: disk_total_values.any? ? (disk_total_values.sum / disk_total_values.size).round(0) : nil,
      iops_r_avg: iops_r_values.any? ? (iops_r_values.sum / iops_r_values.size).round(2) : nil,
      iops_r_max: iops_r_values.max,
      iops_w_avg: iops_w_values.any? ? (iops_w_values.sum / iops_w_values.size).round(2) : nil,
      iops_w_max: iops_w_values.max,
      load1_avg: load1_values.any? ? (load1_values.sum / load1_values.size).round(2) : nil,
      load1_max: load1_values.max,
      load5_avg: load5_values.any? ? (load5_values.sum / load5_values.size).round(2) : nil,
      load15_avg: load15_values.any? ? (load15_values.sum / load15_values.size).round(2) : nil,
      data_points: stats.size
    }
  end
end

