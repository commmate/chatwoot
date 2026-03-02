class CampaignReplyListener < BaseListener
  def message_created(event)
    message = event.data[:message]
    return unless message.incoming? && !message.activity?

    conversation = message.conversation
    inbox = conversation.inbox

    mapping = find_campaign_mapping(message, conversation, inbox)
    return unless mapping

    mark_replied(mapping, conversation)
  end

  private

  def find_campaign_mapping(message, conversation, inbox)
    case inbox.channel_type
    when 'Channel::Email'
      find_email_campaign_mapping(message)
    when 'Channel::Whatsapp'
      find_whatsapp_campaign_mapping(message, conversation)
    when 'Channel::TwilioSms', 'Channel::Sms'
      find_sms_campaign_mapping(conversation)
    when 'Channel::WebWidget'
      find_website_campaign_mapping(conversation)
    end
  end

  def find_email_campaign_mapping(message)
    in_reply_to = message.content_attributes&.dig('email', 'in_reply_to')
    return if in_reply_to.blank?

    CampaignMessageMapping.find_by(resend_email_id: in_reply_to)
  end

  def find_whatsapp_campaign_mapping(message, conversation)
    context_id = message.content_attributes&.dig('in_reply_to_external_id')
    if context_id.present?
      mapping = CampaignMessageMapping.find_by(whatsapp_message_id: context_id)
      return mapping if mapping
    end

    find_by_time_window(conversation.contact_id)
  end

  def find_sms_campaign_mapping(conversation)
    find_by_time_window(conversation.contact_id)
  end

  def find_website_campaign_mapping(conversation)
    return if conversation.campaign_id.blank?

    nil
  end

  def find_by_time_window(contact_id)
    window_hours = GlobalConfig.get_value('CAMPAIGN_REPLY_WINDOW_HOURS')&.to_i || 24
    CampaignMessageMapping
      .where(contact_id: contact_id, replied_at: nil)
      .where(created_at: window_hours.hours.ago..)
      .order(created_at: :desc)
      .first
  end

  def mark_replied(mapping, conversation)
    mapping.update!(replied_at: Time.current)

    campaign = mapping.campaign_delivery_report&.campaign
    return unless campaign

    conversation.update!(campaign_id: campaign.id) if conversation.campaign_id.blank?
  end
end
