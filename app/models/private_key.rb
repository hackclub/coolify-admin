class PrivateKey < ApplicationRecord
  belongs_to :coolify_team

  has_many :servers

  encrypts :private_key

  validates :source, inclusion: { in: %w[manual] }
  validates :name, presence: true, unless: -> { uuid.present? }
end


