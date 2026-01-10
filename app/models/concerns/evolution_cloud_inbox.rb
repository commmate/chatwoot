# frozen_string_literal: true

# EvolutionCloudInbox
#
# Provides predicates to detect Evolution API Cloud WhatsApp inboxes.
# These inboxes use Channel::Api but behave like WhatsApp Cloud for:
# - 24h messaging window enforcement
# - Campaign eligibility
# - Template-required sending outside session window
#
module EvolutionCloudInbox
  extend ActiveSupport::Concern

  # Returns true if this inbox is backed by Evolution API (Cloud or Baileys)
  def evolution_api_inbox?
    return false unless api?
    return false unless channel.respond_to?(:additional_attributes)

    channel.additional_attributes&.dig('evolution_instance_name').present?
  end

  # Returns true if this is an Evolution Cloud WhatsApp API inbox
  # These inboxes should behave like native WhatsApp Cloud (Channel::Whatsapp with provider='whatsapp_cloud')
  def evolution_cloud_whatsapp?
    return false unless evolution_api_inbox?

    channel.additional_attributes&.dig('evolution_channel') == 'whatsapp_cloud_api'
  end

  # Returns true if this is an Evolution Baileys inbox
  def evolution_baileys?
    return false unless evolution_api_inbox?

    channel.additional_attributes&.dig('evolution_channel') == 'baileys'
  end

  # Returns true if this inbox should follow WhatsApp Cloud semantics
  # (used for 24h window, template requirements, etc.)
  def whatsapp_cloud_like?
    whatsapp? && channel.provider == 'whatsapp_cloud' || evolution_cloud_whatsapp?
  end

  # Returns true if this inbox supports WhatsApp campaigns
  def whatsapp_campaign_eligible?
    whatsapp_cloud_like?
  end
end

