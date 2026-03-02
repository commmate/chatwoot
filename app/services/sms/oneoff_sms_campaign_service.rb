class Sms::OneoffSmsCampaignService
  pattr_initialize [:campaign!]

  def perform
    raise "Invalid campaign #{campaign.id}" if campaign.inbox.inbox_type != 'Sms' || !campaign.one_off?
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
    campaign.create_delivery_report!(provider: 'bandwidth', status: 'running', total: total_count, started_at: Time.current)
  end

  def process_contact_with_tracking(contact, report)
    return record_skip(report, contact, 'No phone number') if contact.phone_number.blank?

    send_and_track(contact, report)
  rescue StandardError => e
    report.failed += 1
    report.record_error(code: nil, message: "SMS error: #{e.class.name}", details: e.message)
    Rails.logger.error("[SMS Campaign #{campaign.id}] Failed to send to #{contact.phone_number}: #{e.message}")
  end

  def send_and_track(contact, report)
    content = Liquid::CampaignTemplateService.new(campaign: campaign, contact: contact).call(campaign.message)
    result = channel.send_text_message(contact.phone_number, content)
    report.succeeded += 1
    create_message_mapping(report, contact, result&.dig('id'))
  end

  def record_skip(report, contact, reason)
    report.failed += 1
    report.record_error(code: nil, message: reason, details: "Contact #{contact.name}: #{reason}")
  end

  def create_message_mapping(report, contact, message_id)
    CampaignMessageMapping.create!(
      campaign_delivery_report: report,
      contact: contact,
      sms_message_id: message_id,
      status: 'sent'
    )
  rescue StandardError => e
    Rails.logger.warn("[SMS Campaign #{campaign.id}] Failed to create message mapping: #{e.message}")
  end
end
