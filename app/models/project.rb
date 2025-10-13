class Project < ApplicationRecord
  belongs_to :coolify_team
  has_many :environments, dependent: :destroy
  has_many :resources, through: :environments

  validates :coolify_team_id, :uuid, :name, presence: true
  validates :uuid, uniqueness: { scope: :coolify_team_id }
end

