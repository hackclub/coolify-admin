class CoolifyTeam < ApplicationRecord
  # Rails 7+ Active Record Encryption -> uses token_ciphertext under the hood
  encrypts :token

  validates :name, :base_url, :token, presence: true
  validates :token_fingerprint, presence: true, uniqueness: true
  validates :base_url, format: URI::DEFAULT_PARSER.make_regexp(%w[http https])

  before_validation :fingerprint_token, if: -> { will_save_change_to_token? }
  before_validation :normalize_base_url

  def masked_token
    return "" if token.blank?
    "••••#{token[-4, 4]}"
  end

  private

  def fingerprint_token
    self.token_fingerprint = Digest::SHA256.hexdigest(token.to_s)
  end

  def normalize_base_url
    self.base_url = base_url&.strip&.chomp("/")
  end
end

