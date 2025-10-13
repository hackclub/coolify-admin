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
  attr_reader :prefix

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
      timeout: { connect_timeout:, operation_timeout: },
      max_concurrent_requests: 5  # Limit to 5 concurrent requests to avoid rate limiting
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

  # Simple tree: list servers with their private key names
  def tree
    servers_list = servers()
    Rails.logger.info "📡 Fetched #{servers_list.length} servers"
    
    # Fetch full server details to get private_key_id for each
    server_uuids = servers_list.map { |s| s["uuid"] }
    server_urls = server_uuids.map { |uuid| build_url("/servers/#{uuid}") }
    
    Rails.logger.info "🔄 Fetching full details for #{server_urls.length} servers"
    full_servers = batch_get(server_urls)
    
    # Get all unique private key IDs
    key_ids = full_servers.map { |s| s["private_key_id"] }.compact.uniq
    Rails.logger.info "🔑 Found #{key_ids.length} unique private key IDs: #{key_ids.inspect}"
    
    # Fetch all private keys
    keys_by_id = {}
    if key_ids.any?
      begin
        all_keys = get_json("/security/keys")
        Rails.logger.info "🔍 Got #{all_keys.length} private keys from /security/keys"
        all_keys.each do |key|
          keys_by_id[key["id"]] = key
          Rails.logger.debug "  Key #{key['id']}: #{key['name']}"
        end
      rescue => e
        Rails.logger.error "❌ Failed to fetch private keys: #{e.message}"
      end
    end
    
    # Add key name to each server
    servers_with_keys = full_servers.map do |server|
      if server["private_key_id"] && keys_by_id[server["private_key_id"]]
        server.merge("private_key" => {
          "uuid" => server["private_key_id"],
          "name" => keys_by_id[server["private_key_id"]]["name"]
        })
      else
        server
      end
    end
    
    {
      "servers" => servers_with_keys
    }
  end

  # ---- Endpoints (add more as needed) -----------------------------------------
  def version
    try_get_json("/version")
  end

  def servers
    get_json("/servers")
  end

  def server(uuid)
    get_json("/servers/#{uuid}")
  end

  def projects
    get_json("/projects")
  end

  def project(uuid)
    get_json("/projects/#{uuid}")
  end

  def environments(project_uuid)
    get_json("/projects/#{project_uuid}/environments")
  end

  def resources(environment_uuid)
    get_json("/environments/#{environment_uuid}/resources")
  end

  # If your instance supports per-server project scoping, adapt here.
  def projects_for_server(_server_hash)
    projects
  end

  # New endpoints for sync service
  def current_team
    get_json("/teams/current")
  end

  def applications
    get_json("/applications")
  end

  def services
    get_json("/services")
  end

  def databases
    get_json("/databases")
  end

  # --------------------------- Low-level HTTP ----------------------------------
  private

  def get_json(path)  = request(:get,  path)
  def post_json(path, payload) = request(:post, path, json: payload)

  # Batch GET requests - httpx handles parallelism and rate limiting internally
  def batch_get(urls)
    return [] if urls.empty?
    
    # Make all requests in parallel (httpx handles rate limiting via max_concurrent_requests)
    responses = @http.get(*urls)
    
    # Process all responses
    responses.map do |resp|
      begin
        # Handle HTTPX error responses
        if resp.is_a?(HTTPX::ErrorResponse)
          Rails.logger.warn "Batch request failed: #{resp.error.message}"
          next []
        end
        
        # Return empty array for non-2xx responses (like 404, 429)
        unless resp.status.between?(200, 299)
          Rails.logger.warn "Batch request returned #{resp.status} for #{resp.uri}"
          next []
        end
        
        body = resp.body.to_s
        JSON.parse(body)
      rescue JSON::ParserError => e
        Rails.logger.error "JSON parse error in batch: #{e.message}"
        []
      rescue StandardError => e
        Rails.logger.error "Error in batch processing: #{e.class} - #{e.message}"
        []
      end
    end
  end

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
        else               raise ApiError,          "#{resp.status}: #{snippet(resp)}"
        end
      end

      body = resp.body.to_s
      Rails.logger.debug "  Response status: #{resp.status}, body length: #{body.length}, first 200 chars: #{body[0..200]}"
      JSON.parse(body)
    rescue ConnectionError
      raise if attempts >= 3
      sleep(attempts * 0.15) # tiny backoff
      retry
    rescue UnauthorizedError, NotFoundError, ApiError
      # Let these API errors propagate without retry
      raise
    rescue HTTPX::Error => e
      raise ConnectionError, e.message
    rescue JSON::ParserError => e
      body_preview = resp&.body&.to_s&.[](0..500) || "no body"
      Rails.logger.error "  JSON Parse Error. Response body: #{body_preview}"
      raise ParseError, "Invalid JSON from #{url}: #{e.message}"
    rescue StandardError => e
      raise ParseError, "Unexpected error for #{url}: #{e.class} - #{e.message}"
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
    
    # Try /servers endpoint - we need a successful response (200), not just any response
    resp = get_json("/servers")
    success = resp.is_a?(Array) || resp.is_a?(Hash)
    Rails.logger.debug "  ✅ Prefix '#{prefix}' works!" if success
    success
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

