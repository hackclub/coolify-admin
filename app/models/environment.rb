class Environment < ApplicationRecord
  belongs_to :project
  has_many :resources, dependent: :destroy

  validates :project_id, :environment_id, :name, presence: true
  validates :environment_id, uniqueness: { scope: :project_id }

  # Delegate to project
  delegate :coolify_team, to: :project
  delegate :coolify_team_id, to: :project
end

