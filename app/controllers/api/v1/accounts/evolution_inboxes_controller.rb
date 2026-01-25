# frozen_string_literal: true

# Api::V1::Accounts::EvolutionInboxesController
#
# Handles Evolution API-backed WhatsApp inbox operations (Baileys only).
# All operations are scoped to the current account and resolve Evolution
# instance names from inbox metadata - never accepting instance names from clients.
#
# Authorization: Uses InboxPolicy#update? which allows admins and users with
# settings_inboxes_manage permission.
#
class Api::V1::Accounts::EvolutionInboxesController < Api::V1::Accounts::BaseController
  include EvolutionInboxHelper
  include EvolutionPhoneHelper

  before_action :check_admin_authorization!, only: [:create]
  before_action :fetch_inbox, except: [:create, :status]
  before_action :authorize_inbox_update!, except: [:create, :status]
  before_action :validate_evolution_inbox!, except: [:create, :status]

  # POST /api/v1/accounts/:account_id/evolution/inboxes
  def create
    provisioner = EvolutionApi::InboxProvisioner.new(
      account: Current.account,
      inbox_name: provision_params[:inbox_name],
      user: Current.user
    )
    @inbox = provisioner.provision!
    render json: inbox_response(@inbox), status: :created
  rescue EvolutionApi::InboxProvisioner::ProvisioningError => e
    handle_provisioning_error(e)
  rescue StandardError => e
    handle_unexpected_error(e)
  end

  # GET /api/v1/accounts/:account_id/evolution/inboxes/:inbox_id/chatwoot
  def chatwoot_settings
    settings = evolution_client.find_chatwoot_integration(instance_name: evolution_instance_name)
    render json: sanitize_chatwoot_settings(settings)
  rescue EvolutionApi::Client::ApiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # PUT /api/v1/accounts/:account_id/evolution/inboxes/:inbox_id/chatwoot
  def update_chatwoot_settings
    evolution_client.set_chatwoot_integration(
      instance_name: evolution_instance_name,
      chatwoot_config: build_chatwoot_update_config
    )
    settings = evolution_client.find_chatwoot_integration(instance_name: evolution_instance_name)
    render json: sanitize_chatwoot_settings(settings)
  rescue EvolutionApi::Client::ApiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # GET /api/v1/accounts/:account_id/evolution/inboxes/:inbox_id/connection
  def connection
    render json: evolution_client.connection_state(instance_name: evolution_instance_name)
  rescue EvolutionApi::Client::ApiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # GET /api/v1/accounts/:account_id/evolution/inboxes/:inbox_id/qrcode
  def qrcode
    render json: evolution_client.connect_instance(instance_name: evolution_instance_name)
  rescue EvolutionApi::Client::ApiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/evolution/inboxes/:inbox_id/enable_integration
  def enable_integration
    return render_not_connected_error unless whatsapp_connected?

    update_phone_number_from_instance
    evolution_client.set_chatwoot_integration(
      instance_name: evolution_instance_name,
      chatwoot_config: build_enable_integration_config
    )
    persist_evolution_token_binding!
    render json: { message: 'Integration enabled successfully', connected: true }
  rescue EvolutionApi::Client::ApiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/evolution/inboxes/:inbox_id/restart
  def restart
    render json: evolution_client.restart_instance(instance_name: evolution_instance_name)
  rescue EvolutionApi::Client::ApiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/evolution/inboxes/:inbox_id/logout
  def logout
    result = evolution_client.logout_instance(instance_name: evolution_instance_name)
    clear_phone_number_from_inbox
    render json: result
  rescue EvolutionApi::Client::ApiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/evolution/inboxes/:inbox_id/refresh
  def refresh
    state = evolution_client.connection_state(instance_name: evolution_instance_name)
    update_phone_number_from_instance if state.dig('instance', 'state') == 'open'
    render json: state
  rescue EvolutionApi::Client::ApiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # GET /api/v1/accounts/:account_id/evolution/inboxes/:inbox_id/instance_settings
  def instance_settings
    render json: evolution_client.find_settings(instance_name: evolution_instance_name)
  rescue EvolutionApi::Client::ApiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # PUT /api/v1/accounts/:account_id/evolution/inboxes/:inbox_id/instance_settings
  def update_instance_settings
    settings = evolution_client.set_settings(
      instance_name: evolution_instance_name,
      settings: instance_settings_params
    )
    render json: settings
  rescue EvolutionApi::Client::ApiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/evolution/inboxes/:inbox_id/reauthenticate
  def reauthenticate
    evolution_client.set_chatwoot_integration(
      instance_name: evolution_instance_name,
      chatwoot_config: build_chatwoot_update_config
    )
    persist_evolution_token_binding!
    render json: { message: I18n.t('evolution.reauthenticate_success') }
  rescue EvolutionApi::Client::ApiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # GET /api/v1/accounts/:account_id/evolution/status
  def status
    render json: {
      enabled: evolution_enabled?,
      configured: evolution_enabled? && evolution_configured?,
      healthy: evolution_enabled? && evolution_configured? && check_evolution_health
    }
  end

  private

  def check_admin_authorization!
    raise Pundit::NotAuthorizedError unless Current.user&.administrator?
  end

  def authorize_inbox_update!
    authorize @inbox, :update?
  end

  def fetch_inbox
    inbox_id = params[:inbox_id] || params[:id]
    @inbox = Current.account.inboxes.find(inbox_id)
    authorize @inbox, :show?
  end

  def provision_params
    params.require(:evolution_inbox).permit(:inbox_name)
  end

  def chatwoot_update_params
    params.permit(
      :sign_msg, :sign_delimiter, :reopen_conversation, :conversation_pending,
      :merge_brazil_contacts, :import_contacts, :import_messages, :days_limit_import_messages
    )
  end

  def instance_settings_params
    permitted = %i[reject_call msg_call groups_ignore always_online read_messages read_status sync_full_history]
    source = params[:evolution_inbox].present? ? params.require(:evolution_inbox) : params
    source.permit(*permitted).to_h.symbolize_keys
  end

  def build_chatwoot_update_config
    chatwoot_update_params.to_h.symbolize_keys.merge(
      url: chatwoot_reachable_url,
      account_id: Current.account.id,
      token: current_user_token,
      name_inbox: @inbox.name,
      auto_create: false
    )
  end

  def build_enable_integration_config
    {
      url: chatwoot_reachable_url, account_id: Current.account.id, token: current_user_token,
      name_inbox: @inbox.name, auto_create: false, enabled: true, sign_msg: true,
      reopen_conversation: true, conversation_pending: false, merge_brazil_contacts: true,
      import_contacts: true, import_messages: true, days_limit_import_messages: 3
    }
  end

  def whatsapp_connected?
    state = evolution_client.connection_state(instance_name: evolution_instance_name)
    state.dig('instance', 'state') == 'open'
  end

  def render_not_connected_error
    render json: { error: 'WhatsApp is not connected. Please scan the QR code first.' }, status: :unprocessable_entity
  end

  def handle_provisioning_error(error)
    Rails.logger.error("Evolution inbox provisioning failed: #{error.message}")
    Rails.logger.error(error.backtrace.join("\n")) if error.backtrace.present?
    render json: { error: format_error_message(error) }, status: :unprocessable_entity
  end

  def handle_unexpected_error(error)
    Rails.logger.error("Unexpected error during Evolution inbox provisioning: #{error.message}")
    Rails.logger.error(error.backtrace.join("\n")) if error.backtrace.present?
    render json: { error: "An unexpected error occurred: #{error.message}" }, status: :internal_server_error
  end
end
