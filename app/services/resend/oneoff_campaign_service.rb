# frozen_string_literal: true

# Resend::OneoffCampaignService
#
# Sends one-off email campaigns via Resend API.
# Supports HTML emails with Liquid template variables.
#
# Usage:
#   Resend::OneoffCampaignService.new(campaign: campaign).perform
#
class Resend::OneoffCampaignService
  pattr_initialize [:campaign!]

  def perform
    validate_basic_campaign!
    # Mark campaign completed immediately to prevent duplicate job pickups
    campaign.completed!
    validate_api_key!
    execute_delivery
  rescue Resend::Client::ConfigurationError => e
    handle_configuration_error(e)
  end

  private

  delegate :inbox, to: :campaign
  delegate :channel, to: :inbox

  def validate_basic_campaign!
    validate_campaign_type!
    validate_campaign_status!
    validate_provider!
  end

  def validate_campaign_type!
    raise "Invalid campaign #{campaign.id}" unless email_campaign? && campaign.one_off?
  end

  def email_campaign?
    campaign.inbox.inbox_type == 'Email'
  end

  def validate_campaign_status!
    raise 'Completed Campaign' if campaign.completed?
  end

  def validate_provider!
    raise 'Resend provider required' unless channel.resend?
  end

  def validate_api_key!
    Rails.logger.info("[Resend Campaign] Validating API key for campaign #{campaign.id}")
    Rails.logger.info("[Resend Campaign] Inbox: #{inbox.id} (#{inbox.name})")
    Rails.logger.info("[Resend Campaign] Channel: #{channel.id}, provider: #{channel.provider}")
    Rails.logger.info("[Resend Campaign] provider_config keys: #{channel.provider_config&.keys&.inspect}")
    Rails.logger.info("[Resend Campaign] provider_config present?: #{channel.provider_config.present?}")

    api_key = channel.provider_config&.dig('api_key')
    if api_key.blank?
      raise Resend::Client::ConfigurationError,
            "Resend API key is not configured for inbox '#{inbox.name}' (ID: #{inbox.id}). Please update inbox settings with your Resend API key."
    end
  end

  def execute_delivery
    contacts = fetch_audience_contacts
    report = initialize_delivery_report(contacts.count)

    Rails.logger.info("[Resend Campaign] Processing #{contacts.count} contacts for campaign #{campaign.id}")
    contacts.each { |contact| process_contact_with_tracking(contact, report) }
    finalize_delivery(report)
  end

  def fetch_audience_contacts
    audience_labels = extract_audience_labels
    campaign.account.contacts.tagged_with(audience_labels, any: true).where.not(email: [nil, ''])
  end

  def extract_audience_labels
    audience_label_ids = campaign.audience.select { |audience| audience['type'] == 'Label' }.pluck('id')
    campaign.account.labels.where(id: audience_label_ids).pluck(:title)
  end

  def initialize_delivery_report(total_count)
    campaign.create_delivery_report!(provider: 'resend', status: 'running', total: total_count, started_at: Time.current)
  end

  def process_contact_with_tracking(contact, report)
    Rails.logger.info("[Resend Campaign] Processing contact: #{contact.name} (#{contact.email})")

    return record_skip_error(report, contact, 'No email address') if contact.email.blank?

    send_and_track(contact, report)
  rescue StandardError => e
    handle_processing_error(report, contact, e)
  end

  def record_skip_error(report, contact, reason)
    Rails.logger.info("[Resend Campaign] Skipping contact #{contact.name} - #{reason}")
    report.failed += 1
    report.record_error(code: nil, message: reason, details: "Contact #{contact.name}: #{reason}")
  end

  def handle_processing_error(report, contact, error)
    Rails.logger.error("[Resend Campaign] Failed to process contact #{contact.name}: #{error.message}")
    Rails.logger.error("Backtrace: #{error.backtrace.first(5).join('\n')}")
    report.failed += 1
    report.record_error(code: nil, message: "Processing error: #{error.class.name}", details: error.message)
  end

  def send_and_track(contact, report)
    email_content = render_email_content(contact)
    result = send_email(contact, email_content)

    if result[:ok]
      report.succeeded += 1
      create_message_mapping(report, contact, result[:email_id]) if result[:email_id].present?
    else
      report.failed += 1
      report.record_error(code: result[:error_code], message: result[:error_message])
    end
  end

  def render_email_content(contact)
    liquid_processor = Liquid::TemplateVariableProcessorService.new(drops: liquid_drops(contact))

    {
      subject: liquid_processor.process_string(campaign_subject),
      html: liquid_processor.process_string(campaign_html_body),
      text: liquid_processor.process_string(campaign_text_body)
    }
  end

  def campaign_subject
    campaign.additional_attributes&.dig('email_subject') || campaign.title
  end

  def campaign_html_body
    # Campaign message can be HTML for email campaigns
    campaign.message
  end

  def campaign_text_body
    # Strip HTML for plain text version
    ActionView::Base.full_sanitizer.sanitize(campaign.message)
  end

  def send_email(contact, content)
    response = client.send_email(
      from: from_address,
      to: contact.email,
      subject: content[:subject],
      html: content[:html],
      text: content[:text],
      reply_to: reply_to_address,
      tags: [
        { name: 'campaign_id', value: campaign.id.to_s },
        { name: 'contact_id', value: contact.id.to_s }
      ]
    )

    { ok: true, email_id: response['id'] }
  rescue Resend::Client::ApiError => e
    { ok: false, error_code: e.error_code, error_message: e.message }
  end

  def client
    @client ||= Resend::Client.new(api_key: channel.provider_config['api_key'])
  end

  def from_address
    from_name = channel.provider_config['from_name'] || inbox.name
    from_email = channel.provider_config['from_email'] || channel.email

    "#{from_name} <#{from_email}>"
  end

  def reply_to_address
    # Get the reply-to email based on the selected option
    # Options: 'imap', 'resend', 'custom' (default: 'resend')
    reply_to_option = campaign.additional_attributes&.dig('reply_to_option') || 'resend'

    reply_email = case reply_to_option
                  when 'imap'
                    # Use IMAP email if configured
                    channel.imap_login.presence || channel.email
                  when 'custom'
                    # Use custom reply-to email from campaign, fall back to channel email
                    campaign.additional_attributes&.dig('reply_to_email').presence || channel.email
                  else # 'resend' or default
                    # Use Resend from_email from provider_config or channel email
                    channel.provider_config['from_email'].presence || channel.email
                  end

    # Format with From Name if available, otherwise just email
    from_name = channel.provider_config['from_name']
    from_name.present? ? "#{from_name} <#{reply_email}>" : reply_email
  end

  def create_message_mapping(report, contact, email_id)
    CampaignMessageMapping.create!(
      campaign_delivery_report: report,
      contact: contact,
      resend_email_id: email_id,
      status: 'sent'
    )
  rescue StandardError => e
    Rails.logger.warn("[Resend Campaign] Failed to create message mapping for campaign #{campaign.id}: #{e.message}")
  end

  def finalize_delivery(report)
    report.finalize!
    Rails.logger.info("[Resend Campaign] Campaign #{campaign.id} delivery completed: #{report.succeeded}/#{report.total} succeeded, #{report.failed} failed")
  end

  def handle_configuration_error(error)
    Rails.logger.error("[Resend Campaign] Configuration error for campaign #{campaign.id}: #{error.message}")
    campaign.completed!

    # Create a delivery report with the configuration error
    report = campaign.create_delivery_report!(
      provider: 'resend',
      status: 'completed_with_errors',
      total: 0,
      succeeded: 0,
      failed: 0,
      started_at: Time.current,
      completed_at: Time.current
    )
    report.record_error(code: 'CONFIGURATION_ERROR', message: error.message, details: 'Please update inbox settings with a valid Resend API key.')
    report.save!
  end

  def liquid_drops(contact)
    {
      'contact' => ContactDrop.new(contact),
      'agent' => UserDrop.new(campaign.sender),
      'inbox' => InboxDrop.new(campaign.inbox),
      'account' => AccountDrop.new(campaign.account)
    }
  end
end

