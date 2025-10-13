# frozen_string_literal: true

require "httpx"

class Coolify
  # -------- Errors (simple & useful) ----------
  class Error < StandardError; end
  class ConnectionError   < Error; end   # network/TLS
  class UnauthorizedError < Error; end   # 401/403
  class NotFoundError     < Error; end   # 404
  class ApiError          < Error; end   # other 4xx/5xx
  class ParseError        < Error; end   # invalid JSON

  # -------- Factory for great DX -------------
  def self.for(team)
    new(
      base_url: team.base_url,
      token: team.token,
      verify_tls: team.verify_tls,
      api_path_prefix: team.api_path_prefix.presence || "",
      connect_timeout: 5,
      operation_timeout: 15
    )
  end

  # -------- Service core ---------------------
  def initialize(base_url:, token:, verify_tls: true, api_path_prefix: "", connect_timeout: 5, operation_timeout: 15)
    @base_url = base_url.to_s.strip.chomp("/")
    raise ArgumentError, "base_url required" if @base_url.empty?
    @token    = token
    @verify   = verify_tls
    @prefix   = normalize_prefix(api_path_prefix)

    ssl_config = {}
    ssl_config[:verify_mode] = @verify ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
    
    @http = HTTPX.with(
      headers: {
        "Authorization" => "Bearer #{@token}",
        "Accept"        => "application/json",
        "Content-Type"  => "application/json"
      },
      ssl:     ssl_config,
      timeout: { connect_timeout:, operation_timeout: }
    )
  end

  # ---- DX helpers -------------------------------------------------------------
  # Auto-detects "" vs "/api" vs "/api/v1" (tries current, "", "/api/v1", "/api"), caches result.
  def ensure_prefix!
    return @prefix if !@prefix.empty? && ping_ok?(@prefix)

    candidates = [@prefix, "", "/api/v1", "/api"].uniq
    chosen = candidates.find { |p| ping_ok?(p) }
    raise ConnectionError, "Unable to determine API prefix for #{@base_url} (tried: #{candidates.join(', ')})" unless chosen

    @prefix = chosen
  end

  # Nice nested structure for your sidebar UI
  # { "servers" => [ { ...server, "projects" => [ { ...project, "environments" => [ { ...env, "resources" => [...] } ] } ] } ] }
  def tree
    ensure_prefix!
    servers().map do |srv|
      projs = projects_for_server(srv) # fallback to all projects
      {
        **srv,
        "projects" => projs.map do |pr|
          envs = environments(pr["uuid"])
          {
            **pr,
            "environments" => envs.map { |env| { **env, "resources" => resources(env["uuid"]) } }
          }
        end
      }
    end.then { |arr| { "servers" => arr } }
  end

  # ---- Endpoints (add more as needed) -----------------------------------------
  def version
    ensure_prefix!
    try_get_json("/version")
  end

  def servers
    ensure_prefix!
    get_json("/servers")
  end

  def server(uuid)
    ensure_prefix!
    get_json("/servers/#{uuid}")
  end

  def projects
    ensure_prefix!
    get_json("/projects")
  end

  def project(uuid)
    ensure_prefix!
    get_json("/projects/#{uuid}")
  end

  def environments(project_uuid)
    ensure_prefix!
    get_json("/projects/#{project_uuid}/environments")
  end

  def resources(environment_uuid)
    ensure_prefix!
    get_json("/environments/#{environment_uuid}/resources")
  end

  # If your instance supports per-server project scoping, adapt here.
  def projects_for_server(_server_hash)
    projects
  end

  # --------------------------- Low-level HTTP ----------------------------------
  private

  def get_json(path)  = request(:get,  path)
  def post_json(path, payload) = request(:post, path, json: payload)

  def request(verb, path, **opts)
    url = build_url(path)
    attempts = 0
    begin
      attempts += 1
      resp = @http.public_send(verb, url, **opts)
      raise ConnectionError, "No response" unless resp
      
      # Handle HTTPX error responses
      if resp.is_a?(HTTPX::ErrorResponse)
        raise ConnectionError, "HTTP request failed: #{resp.error.message}"
      end

      unless resp.status.between?(200, 299)
        case resp.status
        when 401, 403 then raise UnauthorizedError, snippet(resp)
        when 404       then raise NotFoundError,    snippet(resp)
        else               raise ApiError,          "#{resp.status} #{resp.reason}: #{snippet(resp)}"
        end
      end

      body = resp.body.to_s
      Rails.logger.debug "  Response status: #{resp.status}, body length: #{body.length}, first 200 chars: #{body[0..200]}"
      JSON.parse(body)
    rescue HTTPX::Error => e
      raise ConnectionError, e.message
    rescue JSON::ParserError => e
      body_preview = resp.body.to_s[0..500]
      Rails.logger.error "  JSON Parse Error. Response body: #{body_preview}"
      raise ParseError, "Invalid JSON from #{url}: #{e.message}"
    rescue StandardError => e
      raise ParseError, "Error parsing response from #{url}: #{e.message}"
    rescue ConnectionError
      raise if attempts >= 3
      sleep(attempts * 0.15) # tiny backoff
      retry
    end
  end

  def try_get_json(path)
    get_json(path)
  rescue ApiError, NotFoundError, ParseError
    # Try alternate prefixes if first fails
    alternates = case @prefix
                 when "/api/v1" then ["", "/api"]
                 when "/api" then ["", "/api/v1"]
                 else ["/api/v1", "/api"]
                 end
    
    old = @prefix
    alternates.each do |alt|
      @prefix = alt
      begin
        return get_json(path)
      rescue ApiError, NotFoundError, ParseError
        next
      end
    end
    
    @prefix = old
    raise
  end

  def build_url(path)
    path = "/#{path}" unless path.start_with?("/")
    "#{@base_url}#{@prefix}#{path}"
  end

  def normalize_prefix(p)
    p = p.to_s.strip
    return "" if p.empty?
    p.start_with?("/") ? p : "/#{p}"
  end

  def ping_ok?(prefix)
    old = @prefix
    @prefix = prefix
    url = build_url("/servers")
    Rails.logger.debug "  Testing prefix '#{prefix}' -> #{url}"
    
    # Try /servers endpoint instead of /version as it's more reliable
    resp = get_json("/servers")
    success = resp.is_a?(Array) || resp.is_a?(Hash)
    Rails.logger.debug "  ✅ Prefix '#{prefix}' works!" if success
    success
  rescue UnauthorizedError => e
    # If we get unauthorized, the endpoint exists (good!)
    Rails.logger.debug "  ✅ Prefix '#{prefix}' exists (got auth error, which is ok)"
    true
  rescue Error => e
    Rails.logger.debug "  ❌ Prefix '#{prefix}' failed: #{e.class} - #{e.message}"
    false
  ensure
    @prefix = old
  end

  def snippet(resp)
    s = resp.to_s
    s.length > 800 ? "#{s[0,800]}...(truncated)" : s
  end
end

