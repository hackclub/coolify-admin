class ResourcesController < ApplicationController
  def show
    @resource = Resource.includes(:server, :coolify_team, environment: :project).find(params[:id])
    
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
    @stats = @resource.resource_stats
                     .where('captured_at >= ?', @since)
                     .order(captured_at: :asc)
    
    # Get latest stat
    @latest_stat = @resource.resource_stats.order(captured_at: :desc).first
    
    # Prepare chart data
    @chart_data = prepare_chart_data(@stats)
    
    # Get latest stats for summary
    @stats_summary = calculate_stats_summary(@stats)
  end
  
  private
  
  def prepare_chart_data(stats)
    {
      timestamps: stats.map { |s| s.captured_at.to_i * 1000 }, # milliseconds for Chart.js
      cpu: stats.map { |s| s.cpu_pct&.round(2) },
      memory_pct: stats.map { |s| s.mem_pct&.round(2) },
      memory_bytes: stats.map { |s| s.mem_used_bytes },
      disk_persistent: stats.map { |s| s.disk_persistent_bytes },
      disk_runtime: stats.map { |s| s.disk_runtime_bytes },
      disk_total: stats.map { |s| (s.disk_persistent_bytes.to_i + s.disk_runtime_bytes.to_i) },
      zombie_processes: stats.map { |s| s.zombie_processes }
    }
  end
  
  def calculate_stats_summary(stats)
    return {} if stats.empty?
    
    cpu_values = stats.map(&:cpu_pct).compact
    mem_values = stats.map(&:mem_used_bytes).compact
    disk_values = stats.map { |s| (s.disk_persistent_bytes.to_i + s.disk_runtime_bytes.to_i) }
    zombie_values = stats.map(&:zombie_processes).compact
    
    {
      cpu_avg: cpu_values.any? ? (cpu_values.sum / cpu_values.size).round(2) : nil,
      cpu_max: cpu_values.max,
      cpu_min: cpu_values.min,
      mem_avg: mem_values.any? ? (mem_values.sum / mem_values.size).round(0) : nil,
      mem_max: mem_values.max,
      mem_min: mem_values.min,
      disk_avg: disk_values.any? ? (disk_values.sum / disk_values.size).round(0) : nil,
      disk_max: disk_values.max,
      disk_min: disk_values.min,
      zombie_avg: zombie_values.any? ? (zombie_values.sum.to_f / zombie_values.size).round(1) : nil,
      zombie_max: zombie_values.max,
      zombie_current: zombie_values.last,
      data_points: stats.size
    }
  end
end

