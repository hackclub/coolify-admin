class Team < ApplicationRecord
  belongs_to :coolify_team

  validates :coolify_team_id, :team_id, :name, presence: true
  validates :team_id, uniqueness: { scope: :coolify_team_id }

  # Scopes
  scope :personal, -> { where(personal_team: true) }
  scope :shared, -> { where(personal_team: false) }
end

