class ServerStat < ApplicationRecord
  belongs_to :server

  validates :captured_at, presence: true
end







