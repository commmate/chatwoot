# frozen_string_literal: true

class SftpCampaignMailer < ApplicationMailer
  def invalid_upload(entry_name:, reason:, recipients:, details: nil)
    @entry_name = entry_name
    @reason = reason
    @details = details
    mail(to: recipients, subject: I18n.t('sftp_campaign_mailer.invalid_upload.subject', entry_name: entry_name))
  end

  def no_account_found(company_name:, batch_info:, recipients:)
    @company_name = company_name
    @batch_info = batch_info
    mail(to: recipients, subject: I18n.t('sftp_campaign_mailer.no_account_found.subject', company_name: company_name))
  end

  def no_inbox_found(account:, from_domain:, batch_info:, reason:)
    @account = account
    @from_domain = from_domain
    @batch_info = batch_info
    @reason = reason
    admin_emails = account.administrators.pluck(:email)
    return if admin_emails.empty?

    mail(to: admin_emails, subject: I18n.t('sftp_campaign_mailer.no_inbox_found.subject', from_domain: from_domain))
  end

  def connection_error(exception_message:, recipients:)
    @exception_message = exception_message
    mail(to: recipients, subject: I18n.t('sftp_campaign_mailer.connection_error.subject'))
  end
end
