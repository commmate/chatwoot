# frozen_string_literal: true

# Resend::WebhookProvisionService
#
# Creates a Resend webhook for a specific inbox. Uses the master key
# if the domain was provisioned via master key, otherwise uses the inbox's own key.
# Stores the webhook ID and signing secret in provider_config.
#
class Resend::WebhookProvisionService
  def initialize(inbox:)
    @inbox = inbox
    @channel = inbox.channel
  end

  def perform
    client = build_client
    endpoint_url = build_endpoint_url

    response = client.create_webhook(
      endpoint: endpoint_url,
      events: Resend::Client::WEBHOOK_EVENTS
    )

    update_provider_config!(response)

    { success: true, webhook_id: response['id'], signing_secret: response['signing_secret'] }
  rescue Resend::Client::ApiError => e
    Rails.logger.warn("[Resend::WebhookProvisionService] Webhook creation failed for inbox #{@inbox.id}: #{e.message}")
    { success: false, error: e.message, error_code: e.error_code }
  rescue StandardError => e
    Rails.logger.error("[Resend::WebhookProvisionService] Unexpected error: #{e.message}")
    { success: false, error: 'Failed to configure webhook. You can configure it manually in settings.', error_code: 'unknown' }
  end

  private

  def build_client
    if @channel.provider_config&.dig('domain_provisioned')
      master_key = GlobalConfig.get_value('RESEND_MASTER_API_KEY')
      return Resend::Client.new(api_key: master_key) if master_key.present?
    end

    api_key = @channel.provider_config&.dig('api_key')
    raise Resend::Client::ConfigurationError, 'No API key available for webhook creation' if api_key.blank?

    Resend::Client.new(api_key: api_key)
  end

  def build_endpoint_url
    url = @inbox.callback_webhook_url
    if url.blank?
      raise Resend::Client::ConfigurationError,
            'FRONTEND_URL is not configured. Set it in your environment to enable webhook auto-configuration.'
    end

    url
  end

  def update_provider_config!(response)
    config = @channel.provider_config || {}
    config['webhook_signing_secret'] = response['signing_secret']
    config['resend_webhook_id'] = response['id']
    @channel.update!(provider_config: config)
  end
end
