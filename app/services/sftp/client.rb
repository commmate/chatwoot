# frozen_string_literal: true

class Sftp::Client
  attr_reader :remote_path

  def initialize
    @host = GlobalConfigService.load('SFTP_CAMPAIGNS_HOST', '').to_s
    @port = (GlobalConfigService.load('SFTP_CAMPAIGNS_PORT', '22').to_s.presence || '22').to_i
    @username = GlobalConfigService.load('SFTP_CAMPAIGNS_USERNAME', '').to_s
    @private_key = normalize_key(GlobalConfigService.load('SFTP_CAMPAIGNS_PRIVATE_KEY', '').to_s.presence)
    @password = GlobalConfigService.load('SFTP_CAMPAIGNS_PASSWORD', '').to_s.presence
    @remote_path = GlobalConfigService.load('SFTP_CAMPAIGNS_REMOTE_PATH', '/campaigns').to_s
    @sftp = nil
  end

  def connect
    opts = { port: @port }
    if @private_key.present?
      opts[:key_data] = [@private_key]
      opts[:keys] = []
      opts[:keys_only] = true
    elsif @password.present?
      opts[:password] = @password
    end
    @sftp = Net::SFTP.start(@host, @username, opts)
  end

  def disconnect
    @sftp&.session&.close
    @sftp = nil
  end

  def list_directories(remote_path = nil)
    path = remote_path.presence || @remote_path
    entries = @sftp.dir.entries(path)
    entries.select { |e| e.directory? && e.name != '.' && e.name != '..' }.map(&:name)
  end

  def download_batch(remote_dir, local_dir)
    download_recursive(remote_dir, local_dir)
  end

  def remove_batch(remote_dir)
    remove_recursive(remote_dir)
  end

  private

  def download_recursive(remote_path, local_path)
    @sftp.dir.entries(remote_path).each do |entry|
      next if entry.name == '.' || entry.name == '..'

      remote_full = "#{remote_path}/#{entry.name}"
      local_full = File.join(local_path, entry.name)

      if entry.directory?
        FileUtils.mkdir_p(local_full)
        download_recursive(remote_full, local_full)
      else
        @sftp.download!(remote_full, local_full)
      end
    end
  end

  def remove_recursive(remote_path)
    @sftp.dir.entries(remote_path).each do |entry|
      next if entry.name == '.' || entry.name == '..'

      remote_full = "#{remote_path}/#{entry.name}"
      if entry.directory?
        remove_recursive(remote_full)
        @sftp.rmdir!(remote_full)
      else
        @sftp.remove!(remote_full)
      end
    end
    @sftp.rmdir!(remote_path)
  end

  def normalize_key(raw)
    return nil if raw.blank?

    key = raw.gsub('\n', "\n").strip
    return Base64.decode64(key) if !key.start_with?('-----') && key.match?(%r{\A[A-Za-z0-9+/=\s]+\z})

    key
  end
end
