# Disable HTTP Basic Authentication for Mission Control Jobs
Rails.application.config.to_prepare do
  MissionControl::Jobs::ApplicationController.class_eval do
    # Skip authentication
    def authenticate_by_http_basic
      # Do nothing - skip authentication
    end
  end
end

