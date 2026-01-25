# frozen_string_literal: true

# Helper methods for Evolution phone number handling
module EvolutionPhoneHelper
  extend ActiveSupport::Concern

  private

  def update_phone_number_from_instance
    formatted_phone = fetch_formatted_phone_number
    return if formatted_phone.blank?

    update_channel_phone_number(formatted_phone)
  rescue StandardError => e
    Rails.logger.warn("[Evolution] Failed to extract phone number: #{e.message}")
  end

  def fetch_formatted_phone_number
    instance_info = evolution_client.fetch_instance(instance_name: evolution_instance_name)
    instance_data = normalize_instance_data(instance_info)
    owner_jid = extract_owner_jid(instance_data)

    return if owner_jid.blank?

    format_phone_number(owner_jid.to_s.split('@').first)
  end

  def normalize_instance_data(instance_info)
    instance_info.is_a?(Array) ? instance_info.first : instance_info
  end

  def extract_owner_jid(instance_data)
    instance_data&.dig('instance', 'ownerJid') ||
      instance_data&.dig('ownerJid') ||
      instance_data&.dig('owner') ||
      instance_data&.dig('number')
  end

  def format_phone_number(phone_number)
    return if phone_number.blank?

    phone_number.start_with?('+') ? phone_number : "+#{phone_number}"
  end

  def update_channel_phone_number(formatted_phone)
    current_attrs = @inbox.channel.additional_attributes || {}
    @inbox.channel.update!(additional_attributes: current_attrs.merge('phone_number' => formatted_phone))
  end

  def clear_phone_number_from_inbox
    current_attrs = @inbox.channel.additional_attributes || {}
    return if current_attrs['phone_number'].blank?

    current_attrs.delete('phone_number')
    @inbox.channel.update!(additional_attributes: current_attrs)
  rescue StandardError => e
    Rails.logger.warn("[Evolution] Failed to clear phone number: #{e.message}")
  end
end
