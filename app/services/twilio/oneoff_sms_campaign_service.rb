class Twilio::OneoffSmsCampaignService
  pattr_initialize [:campaign!]

  def perform
    raise "Invalid campaign #{campaign.id}" if campaign.inbox.inbox_type != 'Twilio SMS' || !campaign.one_off?
    raise 'Completed Campaign' if campaign.completed?

    campaign.completed!
    execute_delivery
  end

  private

  delegate :inbox, to: :campaign
  delegate :channel, to: :inbox

  def execute_delivery
    contacts = fetch_audience_contacts
    report = initialize_delivery_report(contacts.count)

    contacts.each { |contact| process_contact_with_tracking(contact, report) }
    report.finalize!
  end

  def fetch_audience_contacts
    audience_label_ids = campaign.audience.select { |a| a['type'] == 'Label' }.pluck('id')
    audience_labels = campaign.account.labels.where(id: audience_label_ids).pluck(:title)
    campaign.account.contacts.tagged_with(audience_labels, any: true)
  end

  def initialize_delivery_report(total_count)
    campaign.create_delivery_report!(provider: 'twilio', status: 'running', total: total_count, started_at: Time.current)
  end

  def process_contact_with_tracking(contact, report)
    return record_skip(report, contact, 'No phone number') if contact.phone_number.blank?

    send_and_track(contact, report)
  rescue Twilio::REST::TwilioError, Twilio::REST::RestError => e
    record_failure(report, contact, "Twilio error: #{e.class.name}", e.message)
  rescue StandardError => e
    record_failure(report, contact, "Processing error: #{e.class.name}", e.message)
  end

  def send_and_track(contact, report)
    content = Liquid::CampaignTemplateService.new(campaign: campaign, contact: contact).call(campaign.message)
    result = channel.send_message(to: contact.phone_number, body: content)
    report.succeeded += 1
    create_message_mapping(report, contact, result&.sid)
  end

  def record_failure(report, contact, error_type, detail)
    report.failed += 1
    report.record_error(code: nil, message: error_type, details: detail)
    Rails.logger.error("[Twilio Campaign #{campaign.id}] #{error_type} for #{contact.phone_number}: #{detail}")
  end

  def record_skip(report, contact, reason)
    report.failed += 1
    report.record_error(code: nil, message: reason, details: "Contact #{contact.name}: #{reason}")
  end

  def create_message_mapping(report, contact, message_sid)
    CampaignMessageMapping.create!(
      campaign_delivery_report: report,
      contact: contact,
      sms_message_id: message_sid,
      status: 'sent'
    )
  rescue StandardError => e
    Rails.logger.warn("[Twilio Campaign #{campaign.id}] Failed to create message mapping: #{e.message}")
  end
end
