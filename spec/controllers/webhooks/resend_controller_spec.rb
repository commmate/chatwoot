# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webhooks::ResendController, type: :controller do
  let(:account) { create(:account) }
  let(:resend_channel) { create(:channel_email, :resend_email, account: account) }
  let(:inbox) { resend_channel.inbox }
  let(:email_address) { resend_channel.email }

  describe 'POST #process_payload' do
    context 'when inbox is valid' do
      let(:delivery_payload) do
        {
          type: 'email.delivered',
          data: {
            email_id: 'email_12345',
            to: ['user@example.com'],
            from: email_address
          }
        }
      end

      it 'queues the webhook job and returns ok' do
        expect(Webhooks::ResendEventsJob).to receive(:perform_later)
          .with(inbox_id: inbox.id, payload: hash_including('type' => 'email.delivered'))

        post :process_payload, params: delivery_payload.merge(email: email_address)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when email address is invalid' do
      it 'returns not found' do
        post :process_payload, params: { email: 'nonexistent@example.com', type: 'email.delivered' }

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body['error']).to eq('Invalid inbox')
      end
    end

    context 'when email address belongs to non-resend channel' do
      let(:imap_channel) { create(:channel_email, :imap_email, account: account) }

      it 'returns not found' do
        post :process_payload, params: { email: imap_channel.email, type: 'email.delivered' }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with webhook signature verification' do
      let(:signing_secret) { 'whsec_test_signing_secret_base64==' }
      let(:resend_channel_with_secret) do
        create(:channel_email, account: account, provider: 'resend', provider_config: {
                 'api_key' => 're_test_key',
                 'from_email' => 'signed@example.com',
                 'webhook_signing_secret' => signing_secret
               })
      end
      let(:inbox_with_secret) { resend_channel_with_secret.inbox }
      let(:email_with_secret) { resend_channel_with_secret.email }

      let(:webhook_payload) do
        { type: 'email.delivered', data: { email_id: 'email_123' } }
      end

      context 'when signature is valid' do
        let(:timestamp) { Time.now.to_i.to_s }
        let(:webhook_id) { 'msg_test123' }

        it 'processes the webhook' do
          raw_body = webhook_payload.to_json
          payload_to_sign = "#{webhook_id}.#{timestamp}.#{raw_body}"
          signature = Base64.strict_encode64(
            OpenSSL::HMAC.digest('sha256', Base64.decode64(signing_secret.sub('whsec_', '')), payload_to_sign)
          )

          request.headers['svix-signature'] = "v1,#{signature}"
          request.headers['svix-timestamp'] = timestamp
          request.headers['svix-id'] = webhook_id
          request.headers['Content-Type'] = 'application/json'

          allow(controller).to receive(:request).and_wrap_original do |orig|
            req = orig.call
            allow(req).to receive(:raw_post).and_return(raw_body)
            req
          end

          expect(Webhooks::ResendEventsJob).to receive(:perform_later)

          post :process_payload, params: webhook_payload.merge(email: email_with_secret), as: :json

          expect(response).to have_http_status(:ok)
        end
      end

      context 'when signature is invalid' do
        it 'returns unauthorized' do
          request.headers['svix-signature'] = 'v1,invalid_signature'
          request.headers['svix-timestamp'] = Time.now.to_i.to_s
          request.headers['svix-id'] = 'msg_test123'

          post :process_payload, params: webhook_payload.merge(email: email_with_secret), as: :json

          expect(response).to have_http_status(:unauthorized)
          expect(response.parsed_body['error']).to eq('Invalid signature')
        end
      end

      context 'when timestamp is too old' do
        it 'returns unauthorized' do
          old_timestamp = (10.minutes.ago).to_i.to_s
          request.headers['svix-signature'] = 'v1,some_signature'
          request.headers['svix-timestamp'] = old_timestamp
          request.headers['svix-id'] = 'msg_test123'

          post :process_payload, params: webhook_payload.merge(email: email_with_secret), as: :json

          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context 'when signing secret is not configured' do
      it 'skips signature verification and processes webhook' do
        expect(Webhooks::ResendEventsJob).to receive(:perform_later)

        post :process_payload, params: { email: email_address, type: 'email.sent', data: { email_id: 'e123' } }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with different event types' do
      %w[email.sent email.delivered email.bounced email.failed email.complained email.opened email.clicked].each do |event_type|
        it "processes #{event_type} event" do
          expect(Webhooks::ResendEventsJob).to receive(:perform_later)
            .with(inbox_id: inbox.id, payload: hash_including('type' => event_type))

          post :process_payload, params: { email: email_address, type: event_type, data: { email_id: 'email_test' } }

          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
