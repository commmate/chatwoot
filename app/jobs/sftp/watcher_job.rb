# frozen_string_literal: true

class Sftp::WatcherJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    client = nil
    return unless feature_enabled?('RESEND_ENABLED')
    return unless feature_enabled?('SFTP_CAMPAIGNS_ENABLED')

    client = Sftp::Client.new
    return unless sftp_configured?(client)

    run_watcher(client)
  rescue Net::SSH::Exception, Net::SFTP::Exception, OpenSSL::PKey::PKeyError, SocketError, Errno::ECONNREFUSED => e
    Rails.logger.error "[Sftp::WatcherJob] Connection error: #{e.message}"
    notify_connection_error(e.message)
  ensure
    client&.disconnect
  end

  private

  def sftp_configured?(client)
    client.remote_path.present? &&
      GlobalConfigService.load('SFTP_CAMPAIGNS_HOST', '').to_s.present? &&
      GlobalConfigService.load('SFTP_CAMPAIGNS_USERNAME', '').to_s.present?
  end

  def run_watcher(client)
    client.connect
    remote_path = client.remote_path
    dirs = client.list_directories(remote_path)

    dirs.each do |entry_name|
      remote_dir = "#{remote_path}/#{entry_name}"
      local_dir = Dir.mktmpdir('sftp_batch_')
      client.download_batch(remote_dir, local_dir)
      Sftp::ProcessBatchJob.perform_later(batch_path: local_dir)
      client.remove_batch(remote_dir)
    end
  end

  def feature_enabled?(key)
    value = GlobalConfigService.load(key, 'false')
    value == true || value == 'true'
  end

  def notify_connection_error(exception_message)
    super_admin_emails = SuperAdmin.pluck(:email)
    return if super_admin_emails.empty?

    SftpCampaignMailer.connection_error(
      exception_message: exception_message,
      recipients: super_admin_emails
    ).deliver_later
  end
end
