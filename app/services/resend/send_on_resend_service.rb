# frozen_string_literal: true

# Resend::SendOnResendService
#
# Service to send conversation reply emails via the Resend API.
# Called from Email::SendOnEmailService when the channel is a Resend provider.
#
# Usage:
#   Resend::SendOnResendService.new(message: message).perform
#
class Resend::SendOnResendService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Email
  end

  def perform_reply
    return unless message.email_notifiable_message?

    response = send_via_resend
    message.update!(source_id: response['id'], status: :sent)
    Rails.logger.info("[Resend] Email message #{message.id} sent with source_id: #{response['id']}")
  rescue Resend::Client::ApiError => e
    handle_api_error(e)
  rescue StandardError => e
    handle_generic_error(e)
  end

  def send_via_resend
    client.send_email(
      from: from_address,
      to: to_address,
      subject: email_subject,
      html: html_content,
      text: text_content,
      reply_to: reply_to_address,
      headers: email_headers,
      tags: email_tags
    )
  end

  def client
    @client ||= Resend::Client.new(api_key: channel.provider_config['api_key'])
  end

  def from_address
    from_name = channel.provider_config['from_name'] || inbox.name
    from_email = channel.provider_config['from_email'] || channel.email

    "#{from_name} <#{from_email}>"
  end

  def to_address
    contact.email
  end

  def email_subject
    # Use existing conversation subject or generate one
    existing_subject = conversation.additional_attributes&.dig('mail_subject')
    return "Re: #{existing_subject}" if existing_subject.present?

    "[##{conversation.display_id}] #{inbox.name}"
  end

  def html_content
    # Wrap plain text in basic HTML for better email rendering
    content = message.content || ''

    # If content already contains HTML, return as is
    return content if content.match?(/<[a-z][\s\S]*>/i)

    # Convert plain text to HTML with line breaks
    escaped = ERB::Util.html_escape(content)
    "<div style=\"font-family: sans-serif;\">#{escaped.gsub("\n", '<br>')}</div>"
  end

  def text_content
    message.content || ''
  end

  def reply_to_address
    # Use the channel's reply-to or forward-to email
    channel.forward_to_email || channel.email
  end

  def email_headers
    headers = {}

    # Set custom message ID for threading
    headers['X-Chatwoot-Message-Id'] = message.id.to_s
    headers['X-Chatwoot-Conversation-Id'] = conversation.id.to_s
    headers['X-Chatwoot-Inbox-Id'] = inbox.id.to_s

    # Set In-Reply-To for email threading if we have a previous message ID
    if conversation.additional_attributes&.dig('in_reply_to').present?
      headers['In-Reply-To'] = conversation.additional_attributes['in_reply_to']
    end

    headers
  end

  def email_tags
    [
      { name: 'inbox_id', value: inbox.id.to_s },
      { name: 'conversation_id', value: conversation.id.to_s },
      { name: 'message_id', value: message.id.to_s }
    ]
  end

  def handle_api_error(error)
    error_message = "Resend API Error: #{error.error_code} - #{error.message}"
    Rails.logger.error("[Resend] #{error_message}")
    ChatwootExceptionTracker.new(error, account: message.account).capture_exception
    Messages::StatusUpdateService.new(message, 'failed', error_message).perform
  end

  def handle_generic_error(error)
    Rails.logger.error("[Resend] Error sending email: #{error.message}")
    ChatwootExceptionTracker.new(error, account: message.account).capture_exception
    Messages::StatusUpdateService.new(message, 'failed', error.message).perform
  end
end

