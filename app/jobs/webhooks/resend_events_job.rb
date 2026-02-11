# frozen_string_literal: true

class Webhooks::ResendEventsJob < ApplicationJob
  queue_as :default

  def perform(inbox_id:, payload:)
    @inbox = Inbox.find_by(id: inbox_id)
    return unless @inbox&.channel&.is_a?(Channel::Email) && @inbox.channel.resend?

    @payload = payload.with_indifferent_access
    process_event
  end

  private

  def process_event
    event_type = @payload[:type]
    Rails.logger.info("[Resend Webhook] Processing event: #{event_type} for inbox: #{@inbox.id}")

    case event_type
    when 'email.sent', 'email.delivered', 'email.bounced', 'email.failed',
         'email.delivery_delayed', 'email.complained'
      Resend::DeliveryStatusService.new(inbox: @inbox, payload: @payload).perform
    when 'email.opened', 'email.clicked'
      # Track engagement metrics (optional)
      Resend::DeliveryStatusService.new(inbox: @inbox, payload: @payload).perform
    when 'email.received'
      # Inbound email - process via mailbox
      Resend::InboundEmailService.new(inbox: @inbox, payload: @payload).perform
    else
      Rails.logger.warn("[Resend Webhook] Unknown event type: #{event_type}")
    end
  rescue StandardError => e
    Rails.logger.error("[Resend Webhook] Error processing event: #{e.message}")
    Rails.logger.error(e.backtrace.first(5).join("\n"))
    raise
  end
end

