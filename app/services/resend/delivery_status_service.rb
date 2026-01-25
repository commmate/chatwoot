# frozen_string_literal: true

# Resend::DeliveryStatusService
#
# Processes Resend webhook events to update message delivery status.
# Updates both conversation messages and campaign message mappings.
#
# Resend webhook event types:
# - email.sent: Email successfully sent to Resend servers
# - email.delivered: Email delivered to recipient's server
# - email.bounced: Email bounced (permanent failure)
# - email.failed: Email failed to send
# - email.delivery_delayed: Temporary delivery issue
# - email.complained: Recipient marked as spam
# - email.opened: Recipient opened the email
# - email.clicked: Recipient clicked a link
#
class Resend::DeliveryStatusService
  pattr_initialize [:inbox!, :payload!]

  def perform
    return if email_id.blank?

    update_message_status if message.present?
    update_campaign_mapping_status if campaign_mapping.present?

    Rails.logger.info("[Resend] Processed #{event_type} for email: #{email_id}")
  end

  private

  def event_type
    @payload[:type]
  end

  def event_data
    @payload[:data] || {}
  end

  def email_id
    event_data[:email_id]
  end

  def message
    @message ||= inbox.messages.find_by(source_id: email_id)
  end

  def campaign_mapping
    @campaign_mapping ||= CampaignMessageMapping.find_by(resend_email_id: email_id)
  end

  def update_message_status
    case event_type
    when 'email.sent'
      message.update!(status: :sent)
    when 'email.delivered'
      message.update!(status: :delivered)
    when 'email.bounced'
      handle_bounce
    when 'email.failed'
      handle_failure
    when 'email.delivery_delayed'
      # Keep as sent, just log the delay
      Rails.logger.warn("[Resend] Delivery delayed for message: #{message.id}")
    when 'email.complained'
      handle_complaint
    when 'email.opened'
      track_engagement(:opened)
    when 'email.clicked'
      track_engagement(:clicked)
    end
  end

  def handle_bounce
    bounce_data = event_data[:bounce] || {}
    error_message = "Bounced: #{bounce_data[:message] || 'Unknown reason'}"

    message.update!(
      status: :failed,
      external_error: error_message
    )
  end

  def handle_failure
    error_message = "Failed: #{event_data[:error] || 'Unknown error'}"

    message.update!(
      status: :failed,
      external_error: error_message
    )
  end

  def handle_complaint
    message.update!(
      status: :failed,
      external_error: 'Marked as spam by recipient'
    )
  end

  def track_engagement(engagement_type)
    # Store engagement data in additional_attributes
    additional_attributes = message.additional_attributes || {}
    additional_attributes['resend_engagement'] ||= {}
    additional_attributes['resend_engagement'][engagement_type.to_s] = Time.current.iso8601

    message.update!(additional_attributes: additional_attributes)
  end

  def update_campaign_mapping_status
    status = map_event_to_campaign_status
    return if status.blank?

    errors = build_campaign_errors if %w[email.bounced email.failed email.complained].include?(event_type)
    campaign_mapping.update_from_webhook(status: status, errors: errors)
  end

  def map_event_to_campaign_status
    case event_type
    when 'email.sent'
      'sent'
    when 'email.delivered'
      'delivered'
    when 'email.bounced', 'email.failed', 'email.complained'
      'failed'
    end
  end

  def build_campaign_errors
    case event_type
    when 'email.bounced'
      bounce_data = event_data[:bounce] || {}
      [{ code: 'BOUNCED', title: bounce_data[:message] || 'Email bounced' }]
    when 'email.failed'
      [{ code: 'FAILED', title: event_data[:error] || 'Email failed' }]
    when 'email.complained'
      [{ code: 'SPAM', title: 'Marked as spam by recipient' }]
    else
      []
    end
  end
end

