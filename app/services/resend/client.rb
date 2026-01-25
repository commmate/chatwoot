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
    BASE_URL = 'https://api.resend.com'.freeze

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
    def send_email(from:, to:, subject:, html: nil, text: nil, **options)
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

      request(:post, '/emails', body)
    end

    # Send batch emails (up to 100 at once)
    # @param emails [Array<Hash>] Array of email objects (same structure as send_email)
    # @return [Hash] Response with { data: [{ id: 'email_id' }, ...] }
    def send_batch(emails:)
      raise ArgumentError, 'Batch size cannot exceed 100 emails' if emails.size > 100

      request(:post, '/emails/batch', emails)
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

    def request(method, path, body = nil)
      url = "#{BASE_URL}#{path}"
      options = {
        headers: headers,
        timeout: 30
      }
      options[:body] = body.to_json if body.present?

      Rails.logger.debug("[Resend API] #{method.upcase} #{url}")
      Rails.logger.debug("[Resend API] Body: #{body.inspect}") if body.present?

      response = case method
                 when :get
                   HTTParty.get(url, options)
                 when :post
                   HTTParty.post(url, options)
                 when :put
                   HTTParty.put(url, options)
                 when :patch
                   HTTParty.patch(url, options)
                 when :delete
                   HTTParty.delete(url, options)
                 else
                   raise ArgumentError, "Unsupported HTTP method: #{method}"
                 end

      Rails.logger.debug("[Resend API] Response code: #{response.code}")
      handle_response(response)
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

      error_message = extract_error_message(body)
      error_code = body['name'] if body.is_a?(Hash)

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

