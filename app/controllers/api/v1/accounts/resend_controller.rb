# frozen_string_literal: true

class Api::V1::Accounts::ResendController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :check_resend_enabled
  before_action :find_inbox, only: %i[domain_status verify_domain send_dns_instructions configure_webhook]

  def provision_domain
    result = Resend::DomainProvisionService.new(
      domain_name: provision_params[:domain_name],
      region: provision_params[:region],
      from_email: provision_params[:from_email]
    ).perform

    return render json: { error: result[:error], error_code: result[:error_code] }, status: :unprocessable_entity unless result[:success]

    inbox = create_inbox_from_provision(result)
    sleep(1) # Resend rate limit: 2 req/s
    webhook_result = Resend::WebhookProvisionService.new(inbox: inbox).perform

    render json: {
      inbox: inbox.as_json(include: { channel: { only: %i[id email provider provider_config] } }),
      dns_records: result[:dns_records],
      domain_status: result[:domain_status],
      webhook_configured: webhook_result[:success],
      webhook_error: webhook_result[:error]
    }, status: :created
  end

  def domains
    master_key = GlobalConfig.get_value('RESEND_MASTER_API_KEY')
    return render json: { error: 'Master API key not configured' }, status: :unprocessable_entity if master_key.blank?

    client = Resend::Client.new(api_key: master_key)
    response = client.list_domains
    domains = (response['data'] || []).map do |d|
      { id: d['id'], name: d['name'], status: d['status'], region: d['region'], created_at: d['created_at'] }
    end

    render json: { data: domains }
  rescue Resend::Client::ApiError => e
    render json: { error: e.message, error_code: e.error_code }, status: :unprocessable_entity
  end

  def domain_status
    domain_id = @inbox.channel.provider_config&.dig('resend_domain_id')
    return render json: { error: 'No Resend domain linked to this inbox' }, status: :unprocessable_entity if domain_id.blank?

    domain = build_client_for_inbox.get_domain(domain_id: domain_id)
    sync_domain_status(domain)

    render json: {
      status: domain['status'],
      records: domain['records'] || @inbox.channel.provider_config&.dig('resend_dns_records') || [],
      region: domain['region']
    }
  rescue Resend::Client::ApiError => e
    render json: { error: e.message, error_code: e.error_code }, status: :unprocessable_entity
  end

  def verify_domain
    domain_id = @inbox.channel.provider_config&.dig('resend_domain_id')
    return render json: { error: 'No Resend domain linked to this inbox' }, status: :unprocessable_entity if domain_id.blank?

    client = build_client_for_inbox
    client.verify_domain(domain_id: domain_id)

    render json: { message: 'Domain verification triggered. DNS propagation may take a few hours.' }
  rescue Resend::Client::ApiError => e
    render json: { error: e.message, error_code: e.error_code }, status: :unprocessable_entity
  end

  def send_dns_instructions
    recipient = params[:recipient_email]
    return render json: { error: 'Recipient email is required' }, status: :unprocessable_entity if recipient.blank?

    dns_records = @inbox.channel.provider_config&.dig('resend_dns_records')
    return render json: { error: 'No DNS records available for this inbox' }, status: :unprocessable_entity if dns_records.blank?

    ResendDomainMailer.dns_instructions(@inbox, recipient, dns_records).deliver_later
    render json: { message: 'DNS instructions sent successfully' }
  end

  def configure_webhook
    result = Resend::WebhookProvisionService.new(inbox: @inbox).perform
    return render json: { error: result[:error] }, status: :unprocessable_entity unless result[:success]

    render json: { message: 'Webhook configured successfully', webhook_id: result[:webhook_id] }
  end

  private

  def check_resend_enabled
    resend_enabled = GlobalConfigService.load('RESEND_ENABLED', 'false')
    return if resend_enabled == true || resend_enabled == 'true'

    render json: { error: 'Resend integration is not enabled' }, status: :unprocessable_entity
  end

  def find_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
  end

  def sync_domain_status(domain)
    config = @inbox.channel.provider_config || {}
    return if config['resend_domain_status'] == domain['status']

    config['resend_domain_status'] = domain['status']
    config['resend_dns_records'] = domain['records'] if domain['records'].present?
    @inbox.channel.update!(provider_config: config)
  end

  def build_client_for_inbox
    if @inbox.channel.provider_config&.dig('domain_provisioned')
      master_key = GlobalConfig.get_value('RESEND_MASTER_API_KEY')
      return Resend::Client.new(api_key: master_key) if master_key.present?
    end

    api_key = @inbox.channel.provider_config&.dig('api_key')
    raise Resend::Client::ConfigurationError, 'No API key available' if api_key.blank?

    Resend::Client.new(api_key: api_key)
  end

  def create_inbox_from_provision(result)
    channel = Channel::Email.create!(
      account: Current.account,
      email: provision_params[:from_email],
      provider: 'resend',
      provider_config: {
        'api_key' => result[:api_key],
        'from_email' => provision_params[:from_email],
        'from_name' => provision_params[:from_name].presence || provision_params[:channel_name],
        'resend_domain_id' => result[:domain_id],
        'resend_domain_status' => result[:domain_status],
        'resend_dns_records' => result[:dns_records],
        'resend_api_key_id' => result[:api_key_id],
        'domain_provisioned' => true
      }
    )

    Current.account.inboxes.create!(
      name: provision_params[:channel_name]&.strip,
      channel: channel
    )
  end

  def provision_params
    params.permit(:domain_name, :region, :from_email, :from_name, :channel_name)
  end

  def check_authorization
    authorize :inbox, :create?
  end
end
