class Resource < ApplicationRecord
  # Single Table Inheritance base class
  belongs_to :coolify_team
  belongs_to :server
  belongs_to :environment

  validates :type, :coolify_team_id, :server_id, :environment_id, :uuid, :name, presence: true
  validates :uuid, uniqueness: { scope: :coolify_team_id }

  # STI types
  self.inheritance_column = 'type'

  # Scopes
  scope :by_type, ->(type) { where(type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :running, -> { where(status: 'running') }
  scope :stopped, -> { where.not(status: 'running') }
  scope :for_server, ->(server) { where(server_id: server.id) }
  scope :for_environment, ->(environment) { where(environment_id: environment.id) }

  # Delegate helpers
  delegate :name, to: :server, prefix: true
  delegate :name, to: :environment, prefix: true
  delegate :project, to: :environment

  has_many :resource_stats, dependent: :destroy

  # Status helpers
  def running?
    status == 'running'
  end

  def has_domains?
    fqdn.present?
  end

  def domains
    fqdn&.split(',')&.map(&:strip) || []
  end

  # Generate Coolify admin URL for this resource
  def coolify_url
    return nil unless coolify_team && environment && project
    
    resource_type = case self.class.name
                    when 'Application' then 'application'
                    when 'Service' then 'service'
                    when 'CoolifyDatabase' then 'database'
                    else return nil
                    end
    
    # Try to get environment UUID from metadata, or fall back to environment_id
    env_identifier = environment.metadata['uuid'] || environment.metadata['id'] || environment.environment_id
    
    "#{coolify_team.base_url}/project/#{project.uuid}/environment/#{env_identifier}/#{resource_type}/#{uuid}"
  end
end

