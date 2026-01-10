# frozen_string_literal: true

# Internal::RemoveOrphanEvolutionInstancesJob
#
# Daily job to clean up orphan Evolution instances.
# An orphan is an Evolution instance (with cw-* naming pattern) that has no
# corresponding Chatwoot inbox linked to it.
#
# This handles cases where:
# - User creates an inbox but abandons the wizard before completing
# - Inbox creation fails after Evolution instance is created
# - Manual cleanup of dangling instances
#
class Internal::RemoveOrphanEvolutionInstancesJob < ApplicationJob
  queue_as :low

  def perform
    return unless evolution_enabled? && evolution_configured?

    Rails.logger.info('[EvolutionCleanup] Starting orphan Evolution instance cleanup')

    orphan_instances = find_orphan_instances
    deleted_count = 0

    orphan_instances.each do |instance_name|
      delete_instance(instance_name)
      deleted_count += 1
    rescue StandardError => e
      Rails.logger.error("[EvolutionCleanup] Failed to delete instance #{instance_name}: #{e.message}")
    end

    Rails.logger.info("[EvolutionCleanup] Completed. Deleted #{deleted_count} orphan instances.")
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

  def find_orphan_instances
    # Fetch all instances from Evolution API
    all_instances = evolution_client.fetch_all_instances

    # Filter to only cw-* instances (created by Chatwoot)
    chatwoot_instances = extract_chatwoot_instance_names(all_instances)

    # Get all instance names currently linked to Chatwoot inboxes
    linked_instance_names = Channel::Api
      .where.not(additional_attributes: nil)
      .pluck(:additional_attributes)
      .filter_map { |attrs| attrs['evolution_instance_name'] }
      .to_set

    # Find orphans: instances in Evolution but not linked to any Chatwoot inbox
    chatwoot_instances - linked_instance_names.to_a
  end

  def extract_chatwoot_instance_names(instances_response)
    # Response can be an array or array wrapped in an object
    instances_list = if instances_response.is_a?(Array)
                       instances_response
                     elsif instances_response.is_a?(Hash) && instances_response['instances']
                       instances_response['instances']
                     else
                       []
                     end

    instances_list.filter_map do |instance|
      name = instance['instanceName'] || instance['name'] || instance.dig('instance', 'instanceName')
      # Only include cw-* instances (created by Chatwoot)
      name if name&.start_with?('cw-')
    end
  end

  def delete_instance(instance_name)
    Rails.logger.info("[EvolutionCleanup] Deleting orphan instance: #{instance_name}")
    evolution_client.delete_instance(instance_name: instance_name)
  end
end

