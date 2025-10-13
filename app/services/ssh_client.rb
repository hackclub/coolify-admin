require 'net/ssh'

class SshClient
  DEFAULT_TIMEOUT = 45

  def initialize(host:, user:, private_key:, port: 22)
    @host = host
    @user = user.presence || 'root'
    @port = (port.presence || 22).to_i
    @private_key = private_key
  end

  def exec!(cmd, timeout: DEFAULT_TIMEOUT)
    stdout_data = String.new
    stderr_data = String.new
    exit_code = nil
    done = false

    deadline = Time.now + timeout

    # Normalize key newlines and ensure trailing newline
    key_material = @private_key.to_s.gsub("\r\n", "\n")
    key_material << "\n" unless key_material.end_with?("\n")

    # Use a temp file to satisfy OpenSSH key parser expectations
    require 'tempfile'
    Tempfile.create(['key', '.pem']) do |tf|
      tf.write(key_material)
      tf.flush
      File.chmod(0600, tf.path)

      Net::SSH.start(@host, @user,
        port: @port,
        keys: [tf.path],
        keys_only: true,
        non_interactive: true,
        verify_host_key: :never,
        auth_methods: ['publickey'],
        timeout: timeout
      ) do |ssh|
      ssh.open_channel do |channel|
          # Normalize environment for consistent tool behavior
          normalized_cmd = "env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin LC_ALL=C LANG=C #{cmd}"
          channel.exec(normalized_cmd) do |_ch, success|
          raise "Failed to execute: #{cmd}" unless success

          channel.on_data { |_c, data| stdout_data << data }
          channel.on_extended_data { |_c, _type, data| stderr_data << data }
          channel.on_request('exit-status') { |_c, data| exit_code = data.read_long }
          channel.on_close { done = true }
        end
      end

      # Pump the event loop until command finishes or deadline passes
      until done || Time.now >= deadline
        ssh.process(0.1)
      end
      end
    end

    [exit_code, stdout_data, stderr_data]
  rescue Net::SSH::Exception => e
    raise e
  end
end


