# frozen_string_literal: true

# Configure Active Record Encryption
# These keys MUST be set in environment variables for security

# For Rails 8, we need to configure this early, before the application is configured
ActiveSupport.on_load(:active_record) do
  begin
    primary_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY")
    deterministic_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY")
    key_derivation_salt = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT")
    
    ActiveRecord::Encryption.configure(
      primary_key: primary_key,
      deterministic_key: deterministic_key,
      key_derivation_salt: key_derivation_salt
    )
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

