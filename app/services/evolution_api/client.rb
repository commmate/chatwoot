# frozen_string_literal: true

# EvolutionApi::Client
#
# HTTP client for communicating with Evolution API.
# Handles instance creation, Chatwoot integration configuration, and template management.
#
# Usage:
#   client = EvolutionApi::Client.new
#   client.create_instance(instance_name: 'my-instance', channel: 'baileys', ...)
#   client.find_templates(instance_name: 'my-instance')
#
module EvolutionApi
  class Client
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class ApiError < Error
      attr_reader :status, :response_body

      def initialize(message, status: nil, response_body: nil)
        @status = status
        @response_body = response_body
        super(message)
      end
    end

    SUPPORTED_CHANNELS = %w[baileys whatsapp_cloud_api].freeze

    def initialize(base_url: nil, api_key: nil)
      @base_url = base_url || evolution_api_url
      @api_key = api_key || evolution_api_key

      validate_configuration!
    end

    # Creates a new Evolution instance
    # @param instance_name [String] Unique name for the instance
    # @param channel [String] 'baileys' or 'whatsapp_cloud_api'
    # @param options [Hash] Additional options depending on channel:
    #   For baileys: {}
    #   For whatsapp_cloud_api: { token:, number:, business_id: }
    # @return [Hash] Created instance data
    def create_instance(instance_name:, channel:, options: {})
      validate_channel!(channel)

      body = build_instance_payload(instance_name, channel, options)
      request(:post, '/instance/create', body)
    end

    # Fetches an instance by name
    # @param instance_name [String]
    # @return [Hash] Instance data
    def fetch_instance(instance_name:)
      request(:get, "/instance/fetchInstances?instanceName=#{CGI.escape(instance_name)}")
    end

    # Fetches all instances
    # @return [Array<Hash>] List of all instances
    def fetch_all_instances
      request(:get, '/instance/fetchInstances')
    end

    # Configures Chatwoot integration for an Evolution instance
    # @param instance_name [String]
    # @param chatwoot_config [Hash] Chatwoot integration settings:
    #   { url:, token:, account_id:, sign_msg:, reopen_conversation:, conversation_pending:,
    #     name_inbox:, merge_brazil_contacts:, import_contacts:, import_messages:, days_limit_import_messages:,
    #     auto_create: }
    # @return [Hash] Integration response
    def set_chatwoot_integration(instance_name:, chatwoot_config:)
      body = {
        enabled: true,
        accountId: chatwoot_config[:account_id].to_s,
        token: chatwoot_config[:token],
        url: chatwoot_config[:url],
        signMsg: chatwoot_config.fetch(:sign_msg, true),
        signDelimiter: chatwoot_config.fetch(:sign_delimiter, "\n"),
        reopenConversation: chatwoot_config.fetch(:reopen_conversation, true),
        conversationPending: chatwoot_config.fetch(:conversation_pending, false),
        nameInbox: chatwoot_config[:name_inbox] || instance_name,
        mergeBrazilContacts: chatwoot_config.fetch(:merge_brazil_contacts, true),
        importContacts: chatwoot_config.fetch(:import_contacts, true),
        importMessages: chatwoot_config.fetch(:import_messages, true),
        daysLimitImportMessages: chatwoot_config.fetch(:days_limit_import_messages, 3),
        autoCreate: chatwoot_config.fetch(:auto_create, true)
      }

      request(:post, "/chatwoot/set/#{CGI.escape(instance_name)}", body)
    end

    # Retrieves Chatwoot integration settings for an instance
    # @param instance_name [String]
    # @return [Hash] Current Chatwoot integration settings
    def find_chatwoot_integration(instance_name:)
      request(:get, "/chatwoot/find/#{CGI.escape(instance_name)}")
    end

    # Lists all WhatsApp templates for an instance (Cloud API only)
    # @param instance_name [String]
    # @return [Array<Hash>] List of templates
    def find_templates(instance_name:)
      request(:get, "/template/find/#{CGI.escape(instance_name)}")
    end

    # Creates a new WhatsApp template
    # @param instance_name [String]
    # @param template_data [Hash] Template definition:
    #   { name:, category:, language:, components:, allow_category_change: }
    # @return [Hash] Created template data
    def create_template(instance_name:, template_data:)
      body = {
        name: template_data[:name],
        category: template_data[:category],
        language: template_data[:language],
        components: template_data[:components],
        allowCategoryChange: template_data.fetch(:allow_category_change, true),
        webhookUrl: template_data[:webhook_url]
      }.compact

      request(:post, "/template/create/#{CGI.escape(instance_name)}", body)
    end

    # Edits an existing WhatsApp template
    # @param instance_name [String]
    # @param template_data [Hash] Fields to update:
    #   { template_id:, category:, components:, allow_category_change: }
    # @return [Hash] Updated template data
    def edit_template(instance_name:, template_data:)
      body = {
        templateId: template_data[:template_id],
        category: template_data[:category],
        components: template_data[:components],
        allowCategoryChange: template_data[:allow_category_change]
      }.compact

      request(:post, "/template/edit/#{CGI.escape(instance_name)}", body)
    end

    # Deletes a WhatsApp template
    # @param instance_name [String]
    # @param template_name [String] Name of the template to delete
    # @param hsm_id [String, nil] Optional HSM ID
    # @return [Hash] Deletion result
    def delete_template(instance_name:, template_name:, hsm_id: nil)
      body = { name: template_name }
      body[:hsmId] = hsm_id if hsm_id.present?

      request(:delete, "/template/delete/#{CGI.escape(instance_name)}", body)
    end

    # Gets the connection state of an instance
    # @param instance_name [String]
    # @return [Hash] Connection state
    def connection_state(instance_name:)
      request(:get, "/instance/connectionState/#{CGI.escape(instance_name)}")
    end

    # Generates QR code for Baileys instances
    # @param instance_name [String]
    # @return [Hash] QR code data
    def connect_instance(instance_name:)
      request(:get, "/instance/connect/#{CGI.escape(instance_name)}")
    end

    # Restarts an Evolution instance
    # @param instance_name [String]
    # @return [Hash] Restart result
    def restart_instance(instance_name:)
      request(:post, "/instance/restart/#{CGI.escape(instance_name)}")
    end

    # Logs out (disconnects) an instance from WhatsApp
    # @param instance_name [String]
    # @return [Hash] Logout result
    def logout_instance(instance_name:)
      request(:delete, "/instance/logout/#{CGI.escape(instance_name)}")
    end

    # Deletes an Evolution instance
    # @param instance_name [String]
    # @return [Hash] Deletion result
    def delete_instance(instance_name:)
      request(:delete, "/instance/delete/#{CGI.escape(instance_name)}")
    end

    # Fetches instance settings (reject calls, groups ignore, always online, etc.)
    # @param instance_name [String]
    # @return [Hash] Instance settings
    def find_settings(instance_name:)
      request(:get, "/settings/find/#{CGI.escape(instance_name)}")
    end

    # Updates instance settings
    # @param instance_name [String]
    # @param settings [Hash] Settings to update:
    #   { reject_call:, msg_call:, groups_ignore:, always_online:, read_messages:, read_status:, sync_full_history: }
    # @return [Hash] Updated settings
    def set_settings(instance_name:, settings:)
      body = {
        rejectCall: settings[:reject_call],
        msgCall: settings[:msg_call],
        groupsIgnore: settings[:groups_ignore],
        alwaysOnline: settings[:always_online],
        readMessages: settings[:read_messages],
        readStatus: settings[:read_status],
        syncFullHistory: settings[:sync_full_history]
      }.compact

      request(:post, "/settings/set/#{CGI.escape(instance_name)}", body)
    end

    # Sends a text message via Evolution API
    # @param instance_name [String]
    # @param phone_number [String] Recipient phone number (without + prefix)
    # @param text [String] Message text
    # @param options [Hash] Optional params (quoted message, etc.)
    # @return [Hash] Message send result with message ID
    def send_text(instance_name:, phone_number:, text:, options: {})
      body = {
        number: phone_number.to_s.delete('+'),
        text: text
      }
      body[:quoted] = options[:quoted] if options[:quoted].present?

      request(:post, "/message/sendText/#{CGI.escape(instance_name)}", body)
    end

    # Sends a media message via Evolution API
    # @param instance_name [String]
    # @param phone_number [String] Recipient phone number
    # @param media_type [String] 'image', 'video', 'audio', 'document'
    # @param media_url [String] URL to the media file
    # @param options [Hash] Optional params (caption, filename, etc.)
    # @return [Hash] Message send result
    def send_media(instance_name:, phone_number:, media_type:, media_url:, options: {})
      body = {
        number: phone_number.to_s.delete('+'),
        mediatype: media_type,
        media: media_url
      }
      body[:caption] = options[:caption] if options[:caption].present?
      body[:fileName] = options[:filename] if options[:filename].present?

      request(:post, "/message/sendMedia/#{CGI.escape(instance_name)}", body)
    end

    # Sends a WhatsApp template message via Evolution API (Cloud API only)
    # @param instance_name [String]
    # @param phone_number [String] Recipient phone number
    # @param template_name [String] Template name
    # @param language [String] Template language (e.g., 'en_US', 'pt_BR')
    # @param components [Array<Hash>] Template components with parameters
    # @return [Hash] Message send result with message ID
    def send_template(instance_name:, phone_number:, template_name:, language:, components: [])
      body = {
        number: phone_number.to_s.delete('+'),
        name: template_name,
        language: language,
        components: components
      }

      request(:post, "/message/sendTemplate/#{CGI.escape(instance_name)}", body)
    end

    private

    def evolution_api_url
      InstallationConfig.find_by(name: 'EVOLUTION_API_URL')&.value
    end

    def evolution_api_key
      InstallationConfig.find_by(name: 'EVOLUTION_API_KEY')&.value
    end

    def validate_configuration!
      raise ConfigurationError, 'Evolution API URL is not configured' if @base_url.blank?
      raise ConfigurationError, 'Evolution API Key is not configured' if @api_key.blank?
    end

    def validate_channel!(channel)
      return if SUPPORTED_CHANNELS.include?(channel.to_s)

      raise ArgumentError, "Invalid channel: #{channel}. Supported channels: #{SUPPORTED_CHANNELS.join(', ')}"
    end

    def build_instance_payload(instance_name, channel, options)
      base_payload = {
        instanceName: instance_name,
        integration: channel == 'baileys' ? 'WHATSAPP-BAILEYS' : 'WHATSAPP-BUSINESS'
      }

      # For Cloud API, add Meta Business credentials
      if channel == 'whatsapp_cloud_api'
        base_payload.merge!(
          token: options[:token],
          number: options[:number],
          businessId: options[:business_id]
        )
      end

      # NOTE: We never pass Chatwoot config during instance creation.
      # For Baileys: User must scan QR first, then we enable integration.
      # For Cloud API: We call set_chatwoot_integration after instance creation.
      # This prevents restart loops and gives us control over the flow.

      base_payload
    end

    def request(method, path, body = nil)
      url = "#{@base_url}#{path}"
      options = {
        headers: headers
      }
      options[:body] = body.to_json if body.present?

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

      handle_response(response)
    end

    def headers
      {
        'apikey' => @api_key,
        'Content-Type' => 'application/json'
      }
    end

    def handle_response(response)
      body = response.parsed_response

      if response.success?
        # Evolution API sometimes returns 2xx but with Meta API errors in the body
        # Detect and raise these as errors
        if meta_api_error?(body)
          error_message = extract_meta_error_message(body)
          Rails.logger.error("[Evolution API] Meta API error in success response: #{error_message}")
          raise ApiError.new(error_message, status: response.code, response_body: body)
        end
        return body
      end

      error_message = extract_error_message(response)
      
      # Log the full error for debugging
      Rails.logger.error("[Evolution API] Error: #{response.code}")
      Rails.logger.error("[Evolution API] Response body: #{response.body}")
      Rails.logger.error("[Evolution API] Parsed response: #{body.inspect}")
      
      raise ApiError.new(error_message, status: response.code, response_body: body)
    end

    # Detects Meta/Facebook API errors that Evolution passes through
    def meta_api_error?(body)
      return false unless body.is_a?(Hash)

      # Meta API returns errors with 'type' field like 'GraphMethodException', 'OAuthException', etc.
      body['type'].present? && body['code'].present?
    end

    def extract_meta_error_message(body)
      message = body['message'] || 'Unknown Meta API error'
      type = body['type']
      code = body['code']
      "Meta API #{type} (#{code}): #{message}"
    end

    def extract_error_message(response)
      body = response.parsed_response
      
      # Handle string responses (raw text errors)
      return body if body.is_a?(String) && body.present?
      
      # Handle hash responses with various error formats
      if body.is_a?(Hash)
        # Check for nested response.message array (Evolution API format)
        if body['response'].is_a?(Hash) && body['response']['message'].is_a?(Array)
          messages = body['response']['message'].join(', ')
          return messages if messages.present?
        end
        
        # Check for response.message string
        return body['response']['message'] if body['response'].is_a?(Hash) && body['response']['message'].present?
        
        # Check for top-level message
        return body['message'] if body['message'].present?
        
        # Check for nested error.message
        return body['error']['message'] if body['error'].is_a?(Hash) && body['error']['message'].present?
        
        # Check for error as string
        return body['error'] if body['error'].is_a?(String) && body['error'].present?
      end

      "Evolution API request failed with status #{response.code}"
    end
  end
end

