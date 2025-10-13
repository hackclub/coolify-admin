class Application < Resource
  # Application-specific scopes
  scope :by_build_pack, ->(pack) { where("metadata->>'build_pack' = ?", pack) }
  scope :with_git, -> { where("metadata->>'git_repository' IS NOT NULL") }
  scope :dockercompose, -> { where("metadata->>'build_pack' = ?", 'dockercompose') }

  # Application-specific methods
  def git_repository
    metadata['git_repository']
  end

  def git_branch
    metadata['git_branch']
  end

  def build_pack
    metadata['build_pack']
  end

  def docker_compose?
    build_pack == 'dockercompose'
  end

  def docker_compose_raw
    metadata['docker_compose_raw']
  end
end

