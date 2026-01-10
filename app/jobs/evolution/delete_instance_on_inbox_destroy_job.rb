# frozen_string_literal: true

# Evolution::DeleteInstanceOnInboxDestroyJob
#
# Deletes the Evolution instance when a Chatwoot inbox backed by Evolution is destroyed.
# This ensures we don't leave orphan instances in Evolution when inboxes are deleted.
#
class Evolution::DeleteInstanceOnInboxDestroyJob < ApplicationJob
  queue_as :default

  def perform(instance_name)
    return if instance_name.blank?
    return unless evolution_enabled? && evolution_configured?

    Rails.logger.info("[Evolution] Deleting instance #{instance_name} due to inbox deletion")

    evolution_client.delete_instance(instance_name: instance_name)

    Rails.logger.info("[Evolution] Successfully deleted instance #{instance_name}")
  rescue EvolutionApi::Client::ApiError => e
    # Log but don't fail the job - instance may already be deleted
    Rails.logger.warn("[Evolution] Failed to delete instance #{instance_name}: #{e.message}")
  rescue StandardError => e
    Rails.logger.error("[Evolution] Unexpected error deleting instance #{instance_name}: #{e.message}")
    raise
  end

  private

  def evolution_enabled?
    config = InstallationConfig.find_by(name: 'EVOLUTION_API_ENABLED')
    config&.value == true || config&.value == 'true'
  end

  def evolution_configured?
    url = InstallationConfig.find_by(name: 'EVOLUTION_API_URL')&.value
    key = InstallationConfig.find_by(name: 'EVOLUTION_API_KEY')&.value
    url.present? && key.present?
  end

  def evolution_client
    @evolution_client ||= EvolutionApi::Client.new
  end
end

