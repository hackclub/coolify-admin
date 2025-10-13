class Server < ApplicationRecord
  belongs_to :coolify_team
  belongs_to :private_key, optional: true
  has_many :resources, dependent: :destroy
  has_many :server_stats, dependent: :destroy

  validates :coolify_team_id, :uuid, :name, presence: true
  validates :uuid, uniqueness: { scope: :coolify_team_id }

  # Scopes
  scope :reachable, -> { where(is_reachable: true) }
  scope :unreachable, -> { where(is_reachable: false) }
  scope :by_proxy, ->(type) { where(proxy_type: type) }

  # Helper methods
  def reachable?
    is_reachable
  end

  def proxy_enabled?
    proxy_type.present? && proxy_type != 'none'
  end
end

