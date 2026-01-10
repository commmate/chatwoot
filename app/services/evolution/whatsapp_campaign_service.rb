# frozen_string_literal: true

# Evolution::WhatsappCampaignService
#
# Handles WhatsApp campaign execution for Evolution Cloud API inboxes.
# Sends template messages to contacts via Evolution API.
#
class Evolution::WhatsappCampaignService
  pattr_initialize [:campaign!]

  def perform
    validate_campaign!
    # marks campaign completed so that other jobs won't pick it up
    campaign.completed!
    process_audience(extract_audience_labels)
  end

  private

  delegate :inbox, to: :campaign
  delegate :channel, to: :inbox

  def validate_campaign_type!
    raise "Invalid campaign #{campaign.id}" unless evolution_cloud_campaign? && campaign.one_off?
  end

  def evolution_cloud_campaign?
    inbox.evolution_cloud_whatsapp?
  end

  def validate_campaign_status!
    raise 'Completed Campaign' if campaign.completed?
  end

  def validate_feature_flag!
    raise 'WhatsApp campaigns feature not enabled' unless campaign.account.feature_enabled?(:whatsapp_campaign)
  end

  def validate_campaign!
    validate_campaign_type!
    validate_campaign_status!
    validate_feature_flag!
  end

  def extract_audience_labels
    audience_label_ids = campaign.audience.select { |audience| audience['type'] == 'Label' }.pluck('id')
    campaign.account.labels.where(id: audience_label_ids).pluck(:title)
  end

  def process_contact(contact)
    Rails.logger.info "[Evolution Campaign] Processing contact: #{contact.name} (#{contact.phone_number})"

    if contact.phone_number.blank?
      Rails.logger.info "[Evolution Campaign] Skipping contact #{contact.name} - no phone number"
      return
    end

    if campaign.template_params.blank?
      Rails.logger.error "[Evolution Campaign] Skipping contact #{contact.name} - no template_params found"
      return
    end

    send_template_message(to: contact.phone_number, contact: contact)
  end

  def process_audience(audience_labels)
    contacts = campaign.account.contacts.tagged_with(audience_labels, any: true)
    Rails.logger.info "[Evolution Campaign] Processing #{contacts.count} contacts for campaign #{campaign.id}"

    contacts.each { |contact| process_contact(contact) }

    Rails.logger.info "[Evolution Campaign] Campaign #{campaign.id} processing completed"
  end

  def send_template_message(to:, contact:)
    # Process Liquid variables in template_params for this specific contact
    personalized_params = process_liquid_variables(campaign.template_params, contact)

    # Build components array for Evolution API
    components = build_template_components(personalized_params)

    evolution_client.send_template(
      instance_name: evolution_instance_name,
      phone_number: to,
      template_name: personalized_params['name'],
      language: personalized_params['language'] || 'en_US',
      components: components
    )

    Rails.logger.info "[Evolution Campaign] Sent template to #{to}"
  rescue EvolutionApi::Client::ApiError => e
    Rails.logger.error "[Evolution Campaign] Failed to send template to #{to}: #{e.message}"
    # continue processing remaining contacts
    nil
  rescue StandardError => e
    Rails.logger.error "[Evolution Campaign] Unexpected error sending to #{to}: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace&.first(5)&.join('\n')}"
    # continue processing remaining contacts
    nil
  end

  def build_template_components(params)
    components = []

    # Handle processed_params (enhanced format)
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

    components
  end

  def build_header_component(header_params)
    return nil if header_params.blank?

    params = []
    case header_params['type']
    when 'image'
      params << { type: 'image', image: { link: header_params['url'] } } if header_params['url'].present?
    when 'video'
      params << { type: 'video', video: { link: header_params['url'] } } if header_params['url'].present?
    when 'document'
      if header_params['url'].present?
        params << { type: 'document', document: { link: header_params['url'], filename: header_params['filename'] } }
      end
    when 'text'
      params << { type: 'text', text: header_params['text'] } if header_params['text'].present?
    end

    return nil if params.empty?

    { type: 'header', parameters: params }
  end

  def process_liquid_variables(template_params, contact)
    return template_params if template_params.blank?

    # Deep clone to avoid modifying the original
    personalized = template_params.deep_dup

    # Process processed_params if present using the shared Liquid processor service
    if personalized['processed_params'].present?
      liquid_processor = Liquid::TemplateVariableProcessorService.new(drops: liquid_drops(contact))
      personalized['processed_params'] = liquid_processor.process_hash(personalized['processed_params'])
    end

    personalized
  end

  def liquid_drops(contact)
    {
      'contact' => ContactDrop.new(contact),
      'agent' => UserDrop.new(campaign.sender),
      'inbox' => InboxDrop.new(campaign.inbox),
      'account' => AccountDrop.new(campaign.account)
    }
  end

  def evolution_instance_name
    channel.additional_attributes&.dig('evolution_instance_name')
  end

  def evolution_client
    @evolution_client ||= EvolutionApi::Client.new
  end
end

