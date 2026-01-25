# frozen_string_literal: true

# Webhooks::ResendController
#
# Handles webhooks from Resend for:
# - Email delivery status updates (sent, delivered, bounced, failed, etc.)
# - Inbound emails (email.received)
#
# Webhook URL format: POST /webhooks/resend/:email
# Example: POST /webhooks/resend/support@example.com
#
class Webhooks::ResendController < ActionController::API
  before_action :validate_inbox
  before_action :verify_webhook_signature

  def process_payload
    Webhooks::ResendEventsJob.perform_later(inbox_id: @inbox.id, payload: params.to_unsafe_hash)
    head :ok
  end

  private

  def validate_inbox
    email_address = params[:email]
    channel = Channel::Email.find_by(email: email_address, provider: 'resend')
    @inbox = channel&.inbox

    unless @inbox.present?
      Rails.logger.warn("[Resend Webhook] Invalid email address: #{email_address}")
      render json: { error: 'Invalid inbox' }, status: :not_found
    end
  end

  def verify_webhook_signature
    # Resend uses a signature header for webhook verification
    # Header: svix-signature
    # This is optional but recommended for security
    return if skip_signature_verification?

    signature = request.headers['svix-signature']
    timestamp = request.headers['svix-timestamp']
    webhook_id = request.headers['svix-id']

    return if signature.blank?

    signing_secret = @inbox.channel.provider_config['webhook_signing_secret']
    return if signing_secret.blank?

    unless valid_signature?(signature, timestamp, webhook_id, signing_secret)
      Rails.logger.warn("[Resend Webhook] Invalid signature for inbox: #{@inbox.id}")
      render json: { error: 'Invalid signature' }, status: :unauthorized
    end
  end

  def skip_signature_verification?
    # Skip verification if no signing secret is configured
    @inbox.channel.provider_config['webhook_signing_secret'].blank?
  end

  def valid_signature?(signature, timestamp, webhook_id, signing_secret)
    # Resend uses Svix for webhooks
    # Signature format: v1,<base64-signature>
    return false if timestamp.blank? || webhook_id.blank?

    # Check timestamp is within 5 minutes
    timestamp_int = timestamp.to_i
    return false if (Time.now.to_i - timestamp_int).abs > 300

    # Compute expected signature
    payload_to_sign = "#{webhook_id}.#{timestamp}.#{request.raw_post}"
    expected_signature = Base64.strict_encode64(
      OpenSSL::HMAC.digest('sha256', Base64.decode64(signing_secret.sub('whsec_', '')), payload_to_sign)
    )

    # Compare signatures (signature header may contain multiple signatures)
    signature.split(' ').any? do |sig|
      sig_value = sig.split(',').last
      ActiveSupport::SecurityUtils.secure_compare(sig_value, expected_signature)
    end
  rescue StandardError => e
    Rails.logger.error("[Resend Webhook] Signature verification error: #{e.message}")
    false
  end
end

