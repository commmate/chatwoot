# frozen_string_literal: true

# Resend::Client
#
# HTTP client for communicating with the Resend API.
# Handles email sending, batch operations, and domain management.
#
# Resend API Documentation: https://resend.com/docs/api-reference
#
# Usage:
#   client = Resend::Client.new(api_key: 're_xxxxx')
#   client.send_email(
#     from: 'support@mail.example.com',
#     to: 'user@example.com',
#     subject: 'Hello',
#     html: '<p>Hello World</p>'
#   )
#
module Resend
  class Client
    BASE_URL = 'https://api.resend.com'

    VALID_REGIONS = %w[us-east-1 eu-west-1 sa-east-1 ap-northeast-1].freeze
    REGION_LABELS = {
      'us-east-1' => 'N. Virginia (us-east-1)',
      'eu-west-1' => 'Ireland (eu-west-1)',
      'sa-east-1' => 'São Paulo (sa-east-1)',
      'ap-northeast-1' => 'Tokyo (ap-northeast-1)'
    }.freeze

    WEBHOOK_EVENTS = %w[
      email.sent email.delivered email.bounced email.failed
      email.delivery_delayed email.complained email.opened email.clicked
    ].freeze

    DOMAIN_FORMAT = /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+\z/i

    RESEND_ERROR_MAP = {
      'restricted_api_key' => 'This API key only has sending access. A full-access key is required for domain management.',
      'invalid_api_key' => 'The API key is invalid. Please check it and try again.',
      'invalid_region' => 'Invalid region selected.',
      'rate_limit_exceeded' => 'Rate limited by Resend. Please try again in a few seconds.',
      'monthly_quota_exceeded' => 'Monthly email quota exceeded. Please upgrade your Resend plan.',
      'daily_quota_exceeded' => 'Daily email quota exceeded. Please wait 24 hours or upgrade your plan.'
    }.freeze

    class Error < StandardError; end
    class ConfigurationError < Error; end

    class ApiError < Error
      attr_reader :status, :response_body, :error_code

      def initialize(message, status: nil, response_body: nil, error_code: nil)
        @status = status
        @response_body = response_body
        @error_code = error_code
        super(message)
      end
    end

    def initialize(api_key:)
      @api_key = api_key
      validate_configuration!
    end

    # Send a single email
    # @param from [String] Sender email (e.g., 'Support <support@mail.example.com>')
    # @param to [String, Array<String>] Recipient email(s)
    # @param subject [String] Email subject
    # @param html [String] HTML content (optional if text provided)
    # @param text [String] Plain text content (optional if html provided)
    # @param cc [String, Array<String>] CC recipients (optional)
    # @param bcc [String, Array<String>] BCC recipients (optional)
    # @param reply_to [String, Array<String>] Reply-to address(es) (optional)
    # @param headers [Hash] Custom email headers (optional)
    # @param attachments [Array<Hash>] Attachments with { filename:, content: } (optional)
    # @param tags [Array<Hash>] Tags for tracking with { name:, value: } (optional)
    # @return [Hash] Response with { id: 'email_id' }
    def send_email(from:, to:, subject:, html: nil, text: nil, priority: :high, **options)
      body = {
        from: from,
        to: Array(to),
        subject: subject
      }

      body[:html] = html if html.present?
      body[:text] = text if text.present?
      body[:cc] = Array(options[:cc]) if options[:cc].present?
      body[:bcc] = Array(options[:bcc]) if options[:bcc].present?
      body[:reply_to] = options[:reply_to] if options[:reply_to].present?
      body[:headers] = options[:headers] if options[:headers].present?
      body[:attachments] = options[:attachments] if options[:attachments].present?
      body[:tags] = options[:tags] if options[:tags].present?

      request(:post, '/emails', body, priority: priority)
    end

    # Send batch emails (up to 100 at once)
    # @param emails [Array<Hash>] Array of email objects (same structure as send_email)
    # @param priority [Symbol] :high for interactive, :normal for background campaign sends
    # @return [Hash] Response with { data: [{ id: 'email_id' }, ...] }
    def send_batch(emails:, priority: :high)
      raise ArgumentError, 'Batch size cannot exceed 100 emails' if emails.size > 100

      request(:post, '/emails/batch', emails, priority: priority)
    end

    # Get email details by ID
    # @param email_id [String] The email ID returned from send_email
    # @return [Hash] Email details including status
    def get_email(email_id:)
      request(:get, "/emails/#{email_id}")
    end

    # List all domains
    # @return [Hash] Response with { data: [...] }
    def list_domains
      request(:get, '/domains')
    end

    # Get domain details by ID
    # @param domain_id [String] The domain ID
    # @return [Hash] Domain details
    def get_domain(domain_id:)
      request(:get, "/domains/#{domain_id}")
    end

    # Verify a domain
    # @param domain_id [String] The domain ID
    # @return [Hash] Domain verification result
    def verify_domain(domain_id:)
      request(:post, "/domains/#{domain_id}/verify")
    end

    # Create a new domain
    # @param name [String] Domain name (e.g., 'example.com')
    # @param region [String] Region for email sending
    # @return [Hash] Domain details with DNS records
    def create_domain(name:, region: 'eu-west-1')
      raise ArgumentError, "Invalid region: #{region}" unless VALID_REGIONS.include?(region)
      raise ArgumentError, 'Domain name is required' if name.blank?
      raise ArgumentError, "Invalid domain format: #{name}" unless name.match?(DOMAIN_FORMAT)

      request(:post, '/domains', { name: name, region: region })
    end

    # Create an API key
    # @param name [String] Key name (max 50 chars)
    # @param permission [String] 'full_access' or 'sending_access'
    # @param domain_id [String] Restrict to a specific domain (only for sending_access)
    # @return [Hash] { id:, token: }
    def create_api_key(name:, permission: 'sending_access', domain_id: nil)
      raise ArgumentError, 'API key name is required' if name.blank?
      raise ArgumentError, 'API key name must be 50 characters or less' if name.length > 50
      raise ArgumentError, "Invalid permission: #{permission}" unless %w[full_access sending_access].include?(permission)

      body = { name: name, permission: permission }
      body[:domain_id] = domain_id if domain_id.present?
      request(:post, '/api-keys', body)
    end

    # Create a webhook endpoint
    # @param endpoint [String] The URL to receive events
    # @param events [Array<String>] Event types to subscribe to
    # @return [Hash] { id:, signing_secret: }
    def create_webhook(endpoint:, events: WEBHOOK_EVENTS)
      raise ArgumentError, 'Webhook endpoint URL is required' if endpoint.blank?
      raise ArgumentError, 'At least one event type is required' if events.blank?

      request(:post, '/webhooks', { endpoint: endpoint, events: events })
    end

    # Delete a webhook endpoint
    # @param webhook_id [String] The webhook ID
    def delete_webhook(webhook_id:)
      request(:delete, "/webhooks/#{webhook_id}")
    end

    # Performs a health check by listing domains
    # @return [Boolean] true if Resend API is reachable
    def health_check
      list_domains
      true
    rescue StandardError
      false
    end

    private

    def validate_configuration!
      raise ConfigurationError, 'Resend API key is not configured' if @api_key.blank?
    end

    def request(method, path, body = nil, priority: :high)
      url = "#{BASE_URL}#{path}"
      options = {
        headers: headers,
        timeout: 30
      }
      options[:body] = body.to_json if body.present?

      Rails.logger.debug { "[Resend API] #{method.upcase} #{url}" }
      Rails.logger.debug { "[Resend API] Body: #{body.inspect}" } if body.present?

      Resend::RateLimiter.throttle!(priority: priority)
      response = execute_http(method, url, options)

      if response.code == 429
        retry_after = response.headers['retry-after']
        Rails.logger.warn("[Resend API] Rate limited (429), retry-after: #{retry_after || 'nil'}")
        Resend::RateLimiter.backoff!(retry_after)
        Resend::RateLimiter.throttle!(priority: priority)
        response = execute_http(method, url, options)
      end

      Resend::RateLimiter.update_from_headers!(response.headers)

      Rails.logger.debug { "[Resend API] Response code: #{response.code}" }
      handle_response(response)
    end

    def execute_http(method, url, options)
      case method
      when :get    then HTTParty.get(url, options)
      when :post   then HTTParty.post(url, options)
      when :put    then HTTParty.put(url, options)
      when :patch  then HTTParty.patch(url, options)
      when :delete then HTTParty.delete(url, options)
      else raise ArgumentError, "Unsupported HTTP method: #{method}"
      end
    end

    def headers
      {
        'Authorization' => "Bearer #{@api_key}",
        'Content-Type' => 'application/json'
      }
    end

    def handle_response(response)
      body = response.parsed_response

      return body if response.success?

      error_code = body['name'] if body.is_a?(Hash)
      error_message = RESEND_ERROR_MAP[error_code] || extract_error_message(body)

      Rails.logger.error("[Resend API] Error: #{response.code}")
      Rails.logger.error("[Resend API] Response body: #{response.body}")

      raise ApiError.new(
        error_message,
        status: response.code,
        response_body: body,
        error_code: error_code
      )
    end

    def extract_error_message(body)
      return body if body.is_a?(String) && body.present?

      if body.is_a?(Hash)
        # Resend API returns: { "statusCode": 422, "message": "...", "name": "validation_error" }
        return body['message'] if body['message'].present?
        return body['error'] if body['error'].present?
      end

      'Resend API request failed'
    end
  end
end
