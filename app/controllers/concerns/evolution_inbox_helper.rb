# frozen_string_literal: true

# Helper methods for Evolution inbox controllers
module EvolutionInboxHelper
  extend ActiveSupport::Concern
  include EvolutionUrlHelper

  private

  def validate_evolution_enabled!
    return if evolution_enabled?

    render json: { error: 'Evolution API is not enabled for this installation' }, status: :forbidden
  end

  def evolution_enabled?
    config = InstallationConfig.find_by(name: 'EVOLUTION_API_ENABLED')
    config&.value == true || config&.value == 'true'
  end

  def evolution_configured?
    url = InstallationConfig.find_by(name: 'EVOLUTION_API_URL')&.value
    key = InstallationConfig.find_by(name: 'EVOLUTION_API_KEY')&.value
    url.present? && key.present?
  end

  def check_evolution_health
    EvolutionApi::Client.new.health_check
  rescue StandardError
    false
  end

  def evolution_client
    @evolution_client ||= EvolutionApi::Client.new
  end

  def evolution_inbox?
    return false unless @inbox.channel_type == 'Channel::Api'

    evolution_instance_name.present?
  end

  def evolution_instance_name
    @inbox.channel.additional_attributes&.dig('evolution_instance_name')
  end

  def validate_evolution_inbox!
    return if evolution_inbox?

    render json: { error: 'This inbox is not an Evolution API inbox' }, status: :unprocessable_entity
  end

  def current_user_access_token
    @current_user_access_token ||= Current.user.access_token || Current.user.create_access_token
  end

  def current_user_token
    current_user_access_token.token
  end

  def persist_evolution_token_binding!
    access_token = current_user_access_token
    current_attrs = @inbox.channel.additional_attributes || {}

    @inbox.channel.update!(
      additional_attributes: current_attrs.merge(
        'evolution_chatwoot_access_token_id' => access_token.id,
        'evolution_chatwoot_token_owner_id' => Current.user.id,
        'evolution_chatwoot_token_rotated_at' => Time.current.iso8601
      )
    )
  end

  def sanitize_chatwoot_settings(settings)
    settings = settings.dup if settings.is_a?(Hash)
    settings&.except('token', :token)
  end

  def inbox_response(inbox)
    {
      id: inbox.id,
      name: inbox.name,
      channel_type: inbox.channel_type,
      evolution: {
        instance_name: inbox.channel.additional_attributes['evolution_instance_name'],
        channel: inbox.channel.additional_attributes['evolution_channel'],
        url: inbox.channel.additional_attributes['evolution_url']
      }
    }
  end

  def format_error_message(error)
    message = error.message

    if message.include?('Validation failed:')
      message.sub(/^.*Validation failed:\s*/, 'Validation error: ')
    elsif message.include?('Failed to provision Evolution inbox:')
      message
    else
      "Failed to create Evolution inbox: #{message}"
    end
  end
end
