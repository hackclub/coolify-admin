class PrivateKeysController < ApplicationController
  protect_from_forgery with: :null_session

  def edit
    @private_key = PrivateKey.find(params[:id])
  end

  def update
    @private_key = PrivateKey.find(params[:id])
    key_material = params.require(:private_key).permit(:private_key)[:private_key]
    raise ArgumentError, 'private_key is required' if key_material.blank?

    normalized = normalize_pem(key_material)

    # Validate by attempting SSH against the provided server (or any linked)
    server = if params[:server_id].present?
      Server.find_by(id: params[:server_id])
    else
      @private_key.servers.first
    end

    if server.nil?
      flash[:alert] = 'No server associated with this key to validate against.'
      @private_key.private_key = normalized # still prefill textarea with normalized
      return render :edit, status: :unprocessable_entity
    end

    begin
      client = SshClient.new(host: server.ip, user: server.user, port: server.port || 22, private_key: normalized)
      code, _out, err = client.exec!("echo ok", timeout: 6)
      raise StandardError, (err.presence || 'SSH command failed') unless code == 0
    rescue => e
      flash[:alert] = "SSH validation failed: #{e.message}"
      @private_key.private_key = normalized
      return render :edit, status: :unprocessable_entity
    end

    # Save only after successful validation
    @private_key.private_key = normalized
    @private_key.save!

    # Ensure association to server
    server.update!(private_key: @private_key)

    redirect_to root_path, notice: 'SSH key saved and validated.'
  rescue => e
    flash[:alert] = "Failed to save key: #{e.message}"
    render :edit, status: :unprocessable_entity
  end

  def upsert
    server = Server.find(params[:id])
    team = server.coolify_team
    # Expect an existing stub with UUID/name from sync; if not, create stub
    key_uuid = server.metadata.dig('private_key_id') || server.metadata.dig('private_key', 'uuid')
    key_name = server.metadata.dig('private_key', 'name') || "Key for #{server.name}"
    pk = server.private_key || PrivateKey.find_or_initialize_by(coolify_team: team, uuid: key_uuid)
    pk.name ||= key_name
    pk.source = 'manual'
    pk.save!
    server.update!(private_key: pk)

    render json: { success: true, redirect_to: edit_private_key_path(pk, server_id: server.id) }
  rescue => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  private

  # Normalize PEM that may be pasted without newlines, e.g.,
  # "-----BEGIN RSA PRIVATE KEY-----abc...xyz-----END RSA PRIVATE KEY-----"
  def normalize_pem(raw)
    s = raw.to_s.gsub("\r\n", "\n").strip
    # If it already looks like a PEM with separate lines, just ensure trailing newline
    if s.include?("-----BEGIN ") && s.include?("-----END ")
      header_match = s.match(/-----BEGIN ([^-]+)-----/)
      return s << "\n" unless header_match
      label = header_match[1]
      footer_match = s.match(/-----END #{Regexp.escape(label)}-----/)
      return s << "\n" unless footer_match

      # Extract body between header/footer and re-wrap at 64 chars
      body_region = s[header_match.end(0)...footer_match.begin(0)]
      compact = body_region.to_s.gsub(/[ \t\n\r]/, "")
      wrapped = compact.scan(/.{1,64}/).join("\n")
      header = "-----BEGIN #{label}-----"
      footer = "-----END #{label}-----"
      return [header, wrapped, footer, ""].join("\n")
    else
      s << "\n" unless s.end_with?("\n")
      return s
    end
  end
end


