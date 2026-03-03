# frozen_string_literal: true

class ResendDomainMailer < ApplicationMailer
  def dns_instructions(inbox, recipient_email, dns_records)
    return unless smtp_config_set_or_development?

    @inbox = inbox
    @domain_name = inbox.channel.provider_config&.dig('from_email')&.split('@')&.last || 'your domain'
    @dns_records = dns_records
    @brand_name = GlobalConfig.get_value('BRAND_NAME') || 'CommMate'

    subject = "DNS Configuration Required for #{@domain_name}"
    mail(to: recipient_email, subject: subject)
  end
end
