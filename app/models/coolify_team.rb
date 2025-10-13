class CoolifyTeam < ApplicationRecord
  # Rails 7+ Active Record Encryption -> uses token_ciphertext under the hood
  encrypts :token

  validates :name, :base_url, :token, presence: true
  validates :token_fingerprint, presence: true, uniqueness: true
  validates :base_url, format: URI::DEFAULT_PARSER.make_regexp(%w[http https])

  before_validation :fingerprint_token, if: -> { will_save_change_to_token? }
  before_validation :normalize_base_url
  after_validation :detect_api_prefix, on: :create

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

  def detect_api_prefix
    return if api_path_prefix.present? # User manually set it
    return if errors.any? # Don't try to connect if validation already failed
    
    begin
      api = Coolify.for(self)
      api.ensure_prefix!
      self.api_path_prefix = api.prefix
    rescue Coolify::ConnectionError => e
      errors.add(:base, "Cannot connect to Coolify API: #{e.message}")
    rescue Coolify::UnauthorizedError => e
      errors.add(:base, "Invalid API token - authentication failed")
    rescue Coolify::Error => e
      errors.add(:base, "Coolify API error: #{e.message}")
    end
  end
end

