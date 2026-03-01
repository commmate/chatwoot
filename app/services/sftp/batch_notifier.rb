# frozen_string_literal: true

module Sftp::BatchNotifier
  private

  def notify_invalid_upload(reason:, details: nil)
    super_admin_emails = SuperAdmin.pluck(:email)
    return if super_admin_emails.empty?

    SftpCampaignMailer.invalid_upload(
      entry_name: File.basename(@batch_path), reason: reason,
      details: details, recipients: super_admin_emails
    ).deliver_later
  end

  def notify_no_account(company_name, batch_info)
    super_admin_emails = SuperAdmin.pluck(:email)
    return if super_admin_emails.empty?

    SftpCampaignMailer.no_account_found(
      company_name: company_name, batch_info: batch_info, recipients: super_admin_emails
    ).deliver_later
  end

  def notify_no_inbox(account, from_domain, batch_info, reason:)
    SftpCampaignMailer.no_inbox_found(
      account: account, from_domain: from_domain, batch_info: batch_info, reason: reason
    ).deliver_later
  end
end
