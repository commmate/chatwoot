# frozen_string_literal: true

# This initializer hooks into Inbox destroy events to clean up Evolution instances.
# We use this approach instead of modifying the core Inbox model to avoid conflicts
# with upstream Chatwoot code.

Rails.application.config.after_initialize do
  # Ensure Inbox model is loaded
  Inbox.class_eval do
    # We need to capture the instance name BEFORE destroy because
    # the channel is destroyed first (belongs_to :channel, dependent: :destroy)
    # By the time after_destroy_commit runs, the channel is already gone.
    before_destroy :capture_evolution_instance_name
    after_destroy_commit :cleanup_evolution_instance

    private

    def capture_evolution_instance_name
      return unless channel_type == 'Channel::Api'
      return unless channel.respond_to?(:additional_attributes)

      @evolution_instance_name = channel.additional_attributes&.dig('evolution_instance_name')
      Rails.logger.info("[Evolution Cleanup] Captured instance name: #{@evolution_instance_name} for inbox #{id}")
    end

    def cleanup_evolution_instance
      Rails.logger.info("[Evolution Cleanup] cleanup_evolution_instance called for inbox #{id}, instance: #{@evolution_instance_name}")
      return if @evolution_instance_name.blank?

      # Enqueue job to delete the Evolution instance asynchronously
      Rails.logger.info("[Evolution Cleanup] Enqueueing deletion job for instance: #{@evolution_instance_name}")
      Evolution::DeleteInstanceOnInboxDestroyJob.perform_later(@evolution_instance_name)
    end
  end
end

