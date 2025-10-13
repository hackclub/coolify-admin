class Service < Resource
  # Service-specific scopes
  scope :by_service_type, ->(type) { where("metadata->>'service_type' = ?", type) }

  # Service-specific methods
  def service_type
    metadata['service_type']
  end

  def docker_compose_raw
    metadata['docker_compose_raw']
  end

  def one_click_service?
    service_type.present?
  end
end

