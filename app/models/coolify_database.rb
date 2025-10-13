class CoolifyDatabase < Resource
  # Database-specific scopes
  scope :by_database_type, ->(type) { where("metadata->>'database_type' = ?", type) }
  scope :public_databases, -> { where("metadata->>'is_public' = ?", 'true') }
  scope :private_databases, -> { where("metadata->>'is_public' = ?", 'false') }

  # Database-specific methods
  def database_type
    metadata['database_type']
  end

  def image
    metadata['image']
  end

  def is_public?
    metadata['is_public'] == true || metadata['is_public'] == 'true'
  end

  def public_port
    metadata['public_port']
  end
end

