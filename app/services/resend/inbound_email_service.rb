# frozen_string_literal: true

# Resend::InboundEmailService
#
# Processes inbound emails received via Resend webhooks.
# Creates contacts and conversations similar to IMAP mailbox processing.
#
# Resend inbound webhook payload:
# {
#   "type": "email.received",
#   "data": {
#     "email_id": "...",
#     "from": "sender@example.com",
#     "to": ["inbox@mail.example.com"],
#     "subject": "Hello",
#     "html": "<p>Email body</p>",
#     "text": "Email body",
#     "headers": [{"name": "Message-ID", "value": "..."}],
#     "attachments": [{"filename": "file.pdf", "content": "base64...", "content_type": "..."}]
#   }
# }
#
class Resend::InboundEmailService
  include MailboxHelper

  pattr_initialize [:inbox!, :payload!]

  def perform
    @event_data = payload[:data] || {}
    return if @event_data.blank?

    load_channel
    return unless valid_recipient?

    Rails.logger.info("[Resend Inbound] Processing email from: #{from_address} to: #{inbox.name}")

    ActiveRecord::Base.transaction do
      find_or_create_contact
      find_or_create_conversation
      create_message
      process_attachments
    end
  rescue StandardError => e
    Rails.logger.error("[Resend Inbound] Error processing email: #{e.message}")
    Rails.logger.error(e.backtrace.first(5).join("\n"))
    raise
  end

  private

  def load_channel
    @channel = inbox.channel
    @account = inbox.account
  end

  def valid_recipient?
    # Check if the email was sent to this inbox's email
    to_addresses = Array(@event_data[:to])
    inbox_email = @channel.email
    forward_email = @channel.forward_to_email

    to_addresses.any? do |addr|
      addr.downcase.include?(inbox_email.downcase) || addr.downcase.include?(forward_email.downcase)
    end
  end

  def from_address
    @event_data[:from]
  end

  def sender_email
    # Extract email from "Name <email@example.com>" format
    match = from_address&.match(/<(.+?)>/)
    match ? match[1] : from_address
  end

  def sender_name
    # Extract name from "Name <email@example.com>" format
    match = from_address&.match(/^(.+?)\s*</)
    match ? match[1].strip.delete('"') : sender_email&.split('@')&.first
  end

  def subject
    @event_data[:subject] || '(no subject)'
  end

  def html_body
    @event_data[:html]
  end

  def text_body
    @event_data[:text]
  end

  def message_id
    find_header('Message-ID') || @event_data[:email_id]
  end

  def in_reply_to
    find_header('In-Reply-To')
  end

  def references
    ref = find_header('References')
    ref&.split(/\s+/) || []
  end

  def find_header(name)
    headers = @event_data[:headers] || []
    header = headers.find { |h| h[:name]&.downcase == name.downcase }
    header&.dig(:value)
  end

  def find_or_create_contact
    @contact = inbox.contacts.from_email(sender_email)

    if @contact.present?
      @contact_inbox = ContactInbox.find_by(inbox: inbox, contact: @contact)
    else
      create_contact
    end
  end

  def create_contact
    @contact = inbox.account.contacts.create!(
      email: sender_email,
      name: sender_name,
      account_id: inbox.account_id
    )

    @contact_inbox = ContactInbox.create!(
      contact: @contact,
      inbox: inbox,
      source_id: sender_email
    )
  end

  def find_or_create_conversation
    @conversation = find_conversation_by_in_reply_to ||
                    find_conversation_by_references ||
                    create_new_conversation
  end

  def find_conversation_by_in_reply_to
    return if in_reply_to.blank?

    message = inbox.messages.find_by(source_id: in_reply_to)
    return inbox.conversations.find(message.conversation_id) if message.present?

    inbox.conversations.find_by("additional_attributes->>'in_reply_to' = ?", in_reply_to)
  end

  def find_conversation_by_references
    return if references.blank?

    references.each do |ref|
      message = inbox.messages.find_by(source_id: ref)
      return inbox.conversations.find(message.conversation_id) if message.present?
    end

    nil
  end

  def create_new_conversation
    Conversation.create!(
      account_id: @account.id,
      inbox_id: inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id,
      additional_attributes: {
        source: 'email',
        in_reply_to: in_reply_to,
        mail_subject: subject,
        initiated_at: {
          timestamp: Time.current
        }
      }
    )
  end

  def create_message
    content = text_body.presence || ActionView::Base.full_sanitizer.sanitize(html_body)

    @message = @conversation.messages.create!(
      account_id: @account.id,
      inbox_id: inbox.id,
      message_type: :incoming,
      content: content,
      content_type: html_body.present? ? :incoming_email : :text,
      source_id: message_id,
      sender: @contact,
      content_attributes: {
        email: {
          from: [from_address],
          to: @event_data[:to],
          subject: subject,
          html_content: {
            full: html_body,
            reply: html_body
          },
          text_content: {
            full: text_body,
            reply: text_body
          }
        }
      }
    )
  end

  def process_attachments
    attachments = @event_data[:attachments] || []
    return if attachments.blank?

    attachments.each do |attachment|
      next if attachment[:content].blank?

      begin
        decoded_content = Base64.decode64(attachment[:content])
        file = Tempfile.new([attachment[:filename] || 'attachment', ''])
        file.binmode
        file.write(decoded_content)
        file.rewind

        @message.attachments.attach(
          io: file,
          filename: attachment[:filename] || 'attachment',
          content_type: attachment[:content_type] || 'application/octet-stream'
        )
      ensure
        file&.close
        file&.unlink
      end
    end
  rescue StandardError => e
    Rails.logger.error("[Resend Inbound] Error processing attachments: #{e.message}")
  end
end

