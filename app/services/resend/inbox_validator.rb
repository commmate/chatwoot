# frozen_string_literal: true

# Resend::InboxValidator
#
# Validates Resend inbox configuration before creation:
# - Validates API key is valid
# - Validates the from_email domain is verified in Resend
#
# Usage:
#   validator = Resend::InboxValidator.new(
#     api_key: 're_xxxxx',
#     from_email: 'campaigns@mail.example.com'
#   )
#   result = validator.validate
#   # => { valid: true } or { valid: false, error: 'Error message' }
#
class Resend::InboxValidator
  # @param skip_domain_verified [Boolean] when true, only validates the API key (used for new domain flow)
  def initialize(api_key:, from_email:, skip_domain_verified: false)
    @api_key = api_key
    @from_email = from_email
    @skip_domain_verified = skip_domain_verified
  end

  def validate
    return error_result('API key is required') if @api_key.blank?
    return error_result('From email is required') if @from_email.blank?
    return error_result('API key must start with re_') unless @api_key.start_with?('re_')

    return validate_key_only if @skip_domain_verified

    validate_with_resend
  rescue Resend::Client::ConfigurationError => e
    error_result(e.message)
  rescue Resend::Client::ApiError => e
    handle_api_error(e)
  rescue StandardError => e
    Rails.logger.error("[Resend::InboxValidator] Unexpected error: #{e.message}")
    error_result("Failed to validate with Resend: #{e.message}")
  end

  private

  def validate_key_only
    client = Resend::Client.new(api_key: @api_key)
    client.health_check
    { valid: true }
  rescue Resend::Client::ApiError => e
    handle_api_error(e)
  rescue StandardError => e
    error_result("Could not validate API key: #{e.message}")
  end

  def validate_with_resend
    domains = fetch_domains
    email_domain = extract_domain(@from_email)
    return error_result("Invalid email format: #{@from_email}") if email_domain.blank?

    check_domain_status(domains, email_domain)
  end

  def fetch_domains
    client = Resend::Client.new(api_key: @api_key)
    domains_response = client.list_domains
    domains = domains_response['data'] || []
    Rails.logger.info("[Resend::InboxValidator] Found #{domains.count} domains in Resend account")
    domains
  end

  def check_domain_status(domains, email_domain)
    verified_domain = domains.find { |d| d['name'] == email_domain && d['status'] == 'verified' }

    if verified_domain
      Rails.logger.info("[Resend::InboxValidator] Domain '#{email_domain}' is verified")
      return { valid: true }
    end

    build_domain_error(domains, email_domain)
  end

  def build_domain_error(domains, email_domain)
    existing_domain = domains.find { |d| d['name'] == email_domain }
    if existing_domain
      return error_result("Domain '#{email_domain}' exists in Resend but is not verified " \
                          "(status: #{existing_domain['status']}). Please verify the domain first.")
    end

    available_domains = domains.select { |d| d['status'] == 'verified' }.pluck('name')
    if available_domains.any?
      error_result("Domain '#{email_domain}' is not configured in your Resend account. " \
                   "Available verified domains: #{available_domains.join(', ')}")
    else
      error_result("Domain '#{email_domain}' is not configured in your Resend account. " \
                   'Please add and verify this domain in Resend first.')
    end
  end

  def extract_domain(email)
    return nil unless email.include?('@')

    email.split('@').last&.downcase
  end

  def handle_api_error(error)
    case error.status
    when 401, 403
      error_result('Invalid API key. Please check your Resend API key and try again.')
    when 429
      error_result('Rate limited by Resend. Please try again in a few moments.')
    else
      error_result("Resend API error: #{error.message}")
    end
  end

  def error_result(message)
    Rails.logger.warn("[Resend::InboxValidator] Validation failed: #{message}")
    { valid: false, error: message }
  end
end
