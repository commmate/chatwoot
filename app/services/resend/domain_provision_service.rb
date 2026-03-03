# frozen_string_literal: true

class Resend::DomainProvisionService
  def initialize(domain_name:, region:, from_email:)
    @domain_name = domain_name&.downcase&.strip
    @region = region
    @from_email = from_email&.downcase&.strip
  end

  def perform
    validate_inputs!
    master_client = build_master_client!
    check_duplicate_domain!(master_client)
    check_commmate_uniqueness!

    provision_domain_and_key(master_client)
  rescue Resend::Client::ApiError => e
    { success: false, error: e.message, error_code: e.error_code }
  rescue ArgumentError => e
    { success: false, error: e.message, error_code: 'validation_error' }
  rescue StandardError => e
    Rails.logger.error("[Resend::DomainProvisionService] Unexpected error: #{e.message}")
    { success: false, error: 'Could not reach Resend. Please check your connection and try again.', error_code: 'connection_error' }
  end

  private

  def provision_domain_and_key(client)
    domain_response = client.create_domain(name: @domain_name, region: @region)
    domain_id = domain_response['id']
    sleep(1) # Resend rate limit: 2 req/s
    api_key_response = client.create_api_key(
      name: "CommMate - #{@domain_name}"[0, 50],
      permission: 'sending_access',
      domain_id: domain_id
    )

    build_success_result(domain_response, api_key_response)
  end

  def build_success_result(domain_response, api_key_response)
    {
      success: true,
      domain_id: domain_response['id'],
      domain_status: domain_response['status'] || 'not_started',
      dns_records: domain_response['records'] || [],
      api_key: api_key_response['token'],
      api_key_id: api_key_response['id'],
      region: domain_response['region'] || @region
    }
  end

  def validate_inputs!
    raise ArgumentError, 'Domain name is required' if @domain_name.blank?
    raise ArgumentError, "Invalid domain format: #{@domain_name}" unless @domain_name.match?(Resend::Client::DOMAIN_FORMAT)
    raise ArgumentError, "Invalid region: #{@region}" unless Resend::Client::VALID_REGIONS.include?(@region)
    raise ArgumentError, 'From email is required' if @from_email.blank?

    email_domain = @from_email.split('@').last&.downcase
    return if email_domain == @domain_name

    raise ArgumentError, "From email domain (#{email_domain}) must match the domain being created (#{@domain_name})"
  end

  def build_master_client!
    master_key = GlobalConfig.get_value('RESEND_MASTER_API_KEY')
    raise ArgumentError, 'Master Resend API key is not configured. Contact your administrator.' if master_key.blank?

    Resend::Client.new(api_key: master_key)
  end

  def check_duplicate_domain!(client)
    domains_response = client.list_domains
    domains = domains_response['data'] || []
    existing = domains.find { |d| d['name'] == @domain_name }
    sleep(1) # Resend rate limit: 2 req/s
    return unless existing

    raise ArgumentError, "Domain '#{@domain_name}' already exists in Resend (status: #{existing['status']})."
  end

  def check_commmate_uniqueness!
    return unless domain_used_by_existing_inbox?

    raise ArgumentError, "An inbox already exists for the domain '#{@domain_name}'."
  end

  def domain_used_by_existing_inbox?
    Channel::Email.where(provider: 'resend').find_each.any? { |ch| channel_uses_domain?(ch) }
  end

  def channel_uses_domain?(channel)
    extract_domain(channel.email) == @domain_name ||
      extract_domain(channel.provider_config&.dig('from_email')) == @domain_name
  end

  def extract_domain(email_address)
    email_address&.split('@')&.last&.downcase
  end
end
