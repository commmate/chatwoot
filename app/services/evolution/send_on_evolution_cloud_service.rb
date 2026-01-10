# frozen_string_literal: true

# Evolution::SendOnEvolutionCloudService
#
# Handles outbound message sending for Evolution Cloud WhatsApp API inboxes.
# Enforces WhatsApp Cloud semantics: template required when outside 24h window.
#
# This service:
# - Sends template messages when template_params are present OR outside 24h window
# - Sends regular session messages when inside the 24h window
# - Routes all messages through Evolution API
#
class Evolution::SendOnEvolutionCloudService
  pattr_initialize [:message!]

  def perform
    return unless valid_message?

    if should_send_template?
      send_template_message
    else
      send_session_message
    end
  rescue EvolutionApi::Client::ApiError => e
    handle_api_error(e)
  rescue StandardError => e
    handle_unexpected_error(e)
  end

  private

  delegate :conversation, to: :message
  delegate :contact, :contact_inbox, :inbox, to: :conversation
  delegate :channel, to: :inbox

  def valid_message?
    return false unless inbox.evolution_cloud_whatsapp?
    return false unless message.outgoing? || message.template?
    return false if message.private?
    return false if message.source_id.present? # Avoid message loops

    true
  end

  def should_send_template?
    template_params.present? || !conversation.can_reply?
  end

  def send_template_message
    params = template_params
    if params.blank?
      message.update!(status: :failed, external_error: 'Template required but no template_params provided')
      return
    end

    # Process template parameters using the same processor as native WhatsApp
    processed = process_template_params(params)
    if processed[:name].blank?
      message.update!(status: :failed, external_error: 'Template not found or invalid template name')
      return
    end

    result = evolution_client.send_template(
      instance_name: evolution_instance_name,
      phone_number: recipient_phone,
      template_name: processed[:name],
      language: processed[:language],
      components: processed[:components]
    )

    update_message_with_result(result)
  end

  def send_session_message
    result = if message.attachments.present?
               send_media_message
             else
               send_text_message
             end

    update_message_with_result(result)
  end

  def send_text_message
    evolution_client.send_text(
      instance_name: evolution_instance_name,
      phone_number: recipient_phone,
      text: message.content
    )
  end

  def send_media_message
    attachment = message.attachments.first
    media_type = attachment_media_type(attachment)

    evolution_client.send_media(
      instance_name: evolution_instance_name,
      phone_number: recipient_phone,
      media_type: media_type,
      media_url: attachment.download_url,
      options: {
        caption: message.content,
        filename: attachment.file.filename.to_s
      }
    )
  end

  def attachment_media_type(attachment)
    case attachment.file_type
    when 'image' then 'image'
    when 'video' then 'video'
    when 'audio' then 'audio'
    else 'document'
    end
  end

  def process_template_params(params)
    # Build components array for Evolution API
    components = []

    # Handle processed_params (enhanced format used by campaign form)
    if params['processed_params'].present?
      processed = params['processed_params']

      # Header component
      if processed['header'].present?
        header = build_header_component(processed['header'])
        components << header if header
      end

      # Body component
      if processed['body'].present?
        body_params = processed['body'].map { |value| { type: 'text', text: value.to_s } }
        components << { type: 'body', parameters: body_params } if body_params.any?
      end

      # Button components
      if processed['buttons'].present?
        processed['buttons'].each_with_index do |button_value, index|
          next if button_value.blank?

          components << {
            type: 'button',
            sub_type: 'url',
            index: index,
            parameters: [{ type: 'text', text: button_value.to_s }]
          }
        end
      end
    end

    # Handle legacy format (parameters array)
    if params['parameters'].present? && components.empty?
      params['parameters'].each do |component|
        components << component
      end
    end

    {
      name: params['name'],
      language: params['language'] || 'en_US',
      components: components
    }
  end

  def build_header_component(header_params)
    return nil if header_params.blank?

    params = []
    if header_params['type'] == 'image' && header_params['url'].present?
      params << { type: 'image', image: { link: header_params['url'] } }
    elsif header_params['type'] == 'video' && header_params['url'].present?
      params << { type: 'video', video: { link: header_params['url'] } }
    elsif header_params['type'] == 'document' && header_params['url'].present?
      params << { type: 'document', document: { link: header_params['url'], filename: header_params['filename'] } }
    elsif header_params['type'] == 'text' && header_params['text'].present?
      params << { type: 'text', text: header_params['text'] }
    end

    return nil if params.empty?

    { type: 'header', parameters: params }
  end

  def update_message_with_result(result)
    # Evolution API returns message ID in different formats
    message_id = result['key']&.dig('id') || result['messageId'] || result['id']

    if message_id.present?
      message.update!(source_id: message_id, status: :sent)
    else
      message.update!(status: :sent)
    end
  end

  def handle_api_error(error)
    Rails.logger.error("[Evolution] Send message failed: #{error.message}")
    message.update!(
      status: :failed,
      external_error: error.message
    )
  end

  def handle_unexpected_error(error)
    Rails.logger.error("[Evolution] Unexpected error sending message: #{error.message}")
    Rails.logger.error(error.backtrace&.first(5)&.join("\n"))
    message.update!(
      status: :failed,
      external_error: "Unexpected error: #{error.message}"
    )
  end

  def template_params
    message.additional_attributes&.dig('template_params')
  end

  def recipient_phone
    contact_inbox.source_id
  end

  def evolution_instance_name
    channel.additional_attributes&.dig('evolution_instance_name')
  end

  def evolution_client
    @evolution_client ||= EvolutionApi::Client.new
  end
end

