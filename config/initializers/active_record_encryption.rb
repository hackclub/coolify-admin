# frozen_string_literal: true

# Configure Active Record Encryption
# These keys MUST be set in environment variables for security
Rails.application.configure do
  begin
    config.active_record.encryption.primary_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY")
    config.active_record.encryption.deterministic_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY")
    config.active_record.encryption.key_derivation_salt = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT")
  rescue KeyError => e
    raise <<~ERROR
      
      ❌ Missing Active Record Encryption Keys!
      
      The following environment variable is not set: #{e.key}
      
      To fix this:
      
      1. Generate encryption keys by running:
         docker-compose run --rm web bin/rails db:encryption:init
      
      2. Copy the output keys to your .env file:
         
         # .env
         ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=<your_primary_key>
         ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=<your_deterministic_key>
         ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=<your_salt>
      
      3. Restart the application:
         docker-compose restart web
      
      ⚠️  IMPORTANT: 
      - Keep these keys secret and never commit them to git
      - Use different keys for each environment (dev, staging, production)
      - If you lose these keys, you won't be able to decrypt existing data
      
    ERROR
  end
end

