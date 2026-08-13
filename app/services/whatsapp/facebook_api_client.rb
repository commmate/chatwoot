class Whatsapp::FacebookApiClient
  BASE_URI = 'https://graph.facebook.com'.freeze
  # Base webhook fields resent on every subscribe so Meta won't reset to defaults. `calls` is added by callers only when voice is enabled.
  WEBHOOK_DEFAULT_FIELDS = %w[messages smb_message_echoes].freeze

  def initialize(access_token = nil)
    @access_token = access_token
    @api_version = GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
  end

  def exchange_code_for_token(code)
    response = HTTParty.get(
      "#{BASE_URI}/#{@api_version}/oauth/access_token",
      query: {
        client_id: GlobalConfigService.load('WHATSAPP_APP_ID', ''),
        client_secret: GlobalConfigService.load('WHATSAPP_APP_SECRET', ''),
        code: code
      }
    )

    handle_response(response, 'Token exchange failed')
  end

  def fetch_phone_numbers(waba_id)
    response = HTTParty.get(
      "#{BASE_URI}/#{@api_version}/#{waba_id}/phone_numbers",
      query: { access_token: @access_token }
    )

    handle_response(response, 'WABA phone numbers fetch failed')
  end

  def debug_token(input_token)
    response = HTTParty.get(
      "#{BASE_URI}/#{@api_version}/debug_token",
      query: {
        input_token: input_token,
        access_token: build_app_access_token
      }
    )

    handle_response(response, 'Token validation failed')
  end

  def register_phone_number(phone_number_id, pin)
    response = HTTParty.post(
      "#{BASE_URI}/#{@api_version}/#{phone_number_id}/register",
      headers: request_headers,
      body: { messaging_product: 'whatsapp', pin: pin.to_s }.to_json
    )

    handle_response(response, 'Phone registration failed')
  end

  # Releases the number from this app so it can be re-added under another app/BSP. Without this,
  # after an inbox is deleted the number stays registered and Meta reports "already in a partner app".
  def deregister_phone_number(phone_number_id)
    response = HTTParty.post(
      "#{BASE_URI}/#{@api_version}/#{phone_number_id}/deregister",
      headers: request_headers
    )

    handle_response(response, 'Phone deregistration failed')
  end

  def phone_number_verified?(phone_number_id)
    response = HTTParty.get(
      "#{BASE_URI}/#{@api_version}/#{phone_number_id}",
      headers: request_headers
    )

    data = handle_response(response, 'Phone status check failed')
    data['code_verification_status'] == 'VERIFIED'
  end

  def subscribe_phone_number_webhook(waba_id, phone_number_id, callback_url, verify_token, subscribed_fields: nil)
    # Subscribe app to WABA first — Meta requires it before any callback override (issue #13097).
    # subscribed_fields (incl. `calls` when voice is enabled) is declared here; the phone-level POST has no such field.
    subscribe_app_to_waba(waba_id, subscribed_fields: subscribed_fields || WEBHOOK_DEFAULT_FIELDS)

    # Phone-level override takes precedence over WABA-level, so numbers on one WABA can route to different URLs.
    override_phone_number_callback(phone_number_id, callback_url, verify_token)
  end

  def subscribe_app_to_waba(waba_id, subscribed_fields: WEBHOOK_DEFAULT_FIELDS)
    response = HTTParty.post(
      "#{BASE_URI}/#{@api_version}/#{waba_id}/subscribed_apps",
      headers: request_headers,
      body: { subscribed_fields: subscribed_fields }.to_json
    )

    handle_response(response, 'App subscription to WABA failed')
  end

  def override_phone_number_callback(phone_number_id, callback_url, verify_token)
    response = HTTParty.post(
      "#{BASE_URI}/#{@api_version}/#{phone_number_id}",
      headers: request_headers,
      body: {
        webhook_configuration: {
          override_callback_uri: callback_url,
          verify_token: verify_token
        }
      }.to_json
    )

    handle_response(response, 'Phone number webhook callback override failed')
  end

  def clear_phone_number_callback_override(phone_number_id)
    response = HTTParty.post(
      "#{BASE_URI}/#{@api_version}/#{phone_number_id}",
      headers: request_headers,
      body: {
        webhook_configuration: {
          override_callback_uri: ''
        }
      }.to_json
    )

    handle_response(response, 'Phone number webhook callback clear failed')
  end

  # Fully removes this app's WABA subscription (last inbox deleted) so Meta stops delivering webhooks.
  def unsubscribe_app_from_waba(waba_id)
    response = HTTParty.delete(
      "#{BASE_URI}/#{@api_version}/#{waba_id}/subscribed_apps",
      headers: request_headers
    )

    handle_response(response, 'WABA app unsubscription failed')
  end

  def list_message_templates(business_account_id)
    templates = []
    url = "#{BASE_URI}/#{@api_version}/#{business_account_id}/message_templates"

    loop do
      response = HTTParty.get(url, headers: request_headers)
      data = handle_response(response, 'Failed to list message templates')

      templates.concat(data['data'] || [])
      break unless data.dig('paging', 'next')

      url = data['paging']['next']
    end

    templates
  end

  def create_message_template(business_account_id, template_data)
    url = "#{BASE_URI}/#{@api_version}/#{business_account_id}/message_templates"
    Rails.logger.info "[FacebookApiClient] POST #{url} - starting request..."
    start_time = Time.now

    response = HTTParty.post(
      url,
      headers: request_headers,
      body: template_data.to_json,
      verify: false, # Skip SSL CRL verification that causes hangs
      open_timeout: 10,
      read_timeout: 60
    )

    elapsed = ((Time.now - start_time) * 1000).round
    Rails.logger.info "[FacebookApiClient] POST completed in #{elapsed}ms - status: #{response.code}"

    handle_response(response, 'Failed to create message template')
  end

  def delete_message_template(business_account_id, template_name)
    response = HTTParty.delete(
      "#{BASE_URI}/#{@api_version}/#{business_account_id}/message_templates?name=#{template_name}",
      headers: request_headers
    )

    handle_response(response, 'Failed to delete message template')
  end

  # Upload media to Meta and return a handle usable in template creation payloads
  # (example.header_handle for IMAGE/VIDEO/DOCUMENT headers).
  #
  # This follows Meta's upload flow:
  # - POST /{app_id}/uploads -> returns upload session id (id)
  # - POST /{id} with raw bytes -> returns handle (h)
  def upload_template_media(file_bytes:, file_type:)
    app_id = fetch_app_id_from_token
    upload_api_version = GlobalConfigService.load('WHATSAPP_UPLOADS_API_VERSION', 'v24.0')

    session_response = HTTParty.post(
      "#{BASE_URI}/#{upload_api_version}/#{app_id}/uploads",
      headers: request_headers,
      body: {
        file_length: file_bytes.bytesize,
        file_type: file_type
      }.to_json
    )

    session = handle_response(session_response, 'Failed to create upload session')
    upload_id = session['id']
    raise 'Upload session id missing' if upload_id.blank?

    upload_response = HTTParty.post(
      "#{BASE_URI}/#{upload_api_version}/#{upload_id}",
      headers: {
        'Authorization' => "Bearer #{@access_token}",
        'Content-Type' => 'application/octet-stream'
      },
      body: file_bytes
    )

    uploaded = handle_response(upload_response, 'Failed to upload media')
    handle = uploaded['h']
    raise 'Upload handle missing' if handle.blank?

    handle
  end

  private

  def fetch_app_id_from_token
    return @app_id if @app_id.present?

    response = HTTParty.get(
      "#{BASE_URI}/#{@api_version}/debug_token",
      query: {
        input_token: @access_token,
        access_token: @access_token
      }
    )

    data = handle_response(response, 'Token validation failed')
    @app_id = data.dig('data', 'app_id')
    raise 'Failed to determine app_id from token' if @app_id.blank?

    @app_id
  end

  def request_headers
    {
      'Authorization' => "Bearer #{@access_token}",
      'Content-Type' => 'application/json'
    }
  end

  def build_app_access_token
    app_id = GlobalConfigService.load('WHATSAPP_APP_ID', '')
    app_secret = GlobalConfigService.load('WHATSAPP_APP_SECRET', '')
    "#{app_id}|#{app_secret}"
  end

  def handle_response(response, error_message)
    return response.parsed_response if response.success?

    # Extract user-friendly error message from Meta API response
    parsed = response.parsed_response rescue nil
    meta_error = parsed&.dig('error', 'error_user_msg') || parsed&.dig('error', 'message') || response.body
    raise meta_error
  end
end
