class ResourceStat < ApplicationRecord
  belongs_to :resource
  belongs_to :server

  validates :captured_at, presence: true
end







