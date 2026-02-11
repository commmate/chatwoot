# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Resend::Client do
  subject(:client) { described_class.new(api_key: api_key) }

  let(:api_key) { 're_test_abc123' }
  let(:base_url) { 'https://api.resend.com' }

  describe '#initialize' do
    context 'when API key is provided' do
      it 'creates a client successfully' do
        expect { client }.not_to raise_error
      end
    end

    context 'when API key is blank' do
      let(:api_key) { '' }

      it 'raises ConfigurationError' do
        expect { client }.to raise_error(Resend::Client::ConfigurationError, 'Resend API key is not configured')
      end
    end

    context 'when API key is nil' do
      let(:api_key) { nil }

      it 'raises ConfigurationError' do
        expect { client }.to raise_error(Resend::Client::ConfigurationError, 'Resend API key is not configured')
      end
    end
  end

  describe '#send_email' do
    let(:email_params) do
      {
        from: 'Test <test@example.com>',
        to: 'recipient@example.com',
        subject: 'Test Subject',
        html: '<p>Hello World</p>'
      }
    end

    context 'when request is successful' do
      before do
        stub_request(:post, "#{base_url}/emails")
          .with(
            body: {
              from: email_params[:from],
              to: [email_params[:to]],
              subject: email_params[:subject],
              html: email_params[:html]
            }.to_json,
            headers: {
              'Authorization' => "Bearer #{api_key}",
              'Content-Type' => 'application/json'
            }
          )
          .to_return(
            status: 200,
            body: { id: 'email_12345' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'sends email and returns response with email id' do
        response = client.send_email(**email_params)
        expect(response['id']).to eq('email_12345')
      end
    end

    context 'when request includes optional parameters' do
      let(:full_params) do
        email_params.merge(
          cc: 'cc@example.com',
          bcc: ['bcc1@example.com', 'bcc2@example.com'],
          reply_to: 'reply@example.com',
          text: 'Hello World',
          tags: [{ name: 'campaign_id', value: '123' }]
        )
      end

      before do
        stub_request(:post, "#{base_url}/emails")
          .to_return(
            status: 200,
            body: { id: 'email_67890' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'includes optional parameters in request' do
        client.send_email(**full_params)

        expect(WebMock).to have_requested(:post, "#{base_url}/emails")
          .with(body: hash_including(
            'cc' => ['cc@example.com'],
            'bcc' => ['bcc1@example.com', 'bcc2@example.com'],
            'reply_to' => 'reply@example.com',
            'text' => 'Hello World',
            'tags' => [{ 'name' => 'campaign_id', 'value' => '123' }]
          ))
      end
    end

    context 'when API returns an error' do
      before do
        stub_request(:post, "#{base_url}/emails")
          .to_return(
            status: 422,
            body: {
              statusCode: 422,
              message: "Invalid 'reply_to' field",
              name: 'validation_error'
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises ApiError with error details' do
        expect { client.send_email(**email_params) }.to raise_error(Resend::Client::ApiError) do |error|
          expect(error.message).to eq("Invalid 'reply_to' field")
          expect(error.status).to eq(422)
          expect(error.error_code).to eq('validation_error')
        end
      end
    end

    context 'when API returns rate limit error' do
      before do
        stub_request(:post, "#{base_url}/emails")
          .to_return(
            status: 429,
            body: { message: 'Rate limit exceeded' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises ApiError with rate limit message' do
        expect { client.send_email(**email_params) }.to raise_error(Resend::Client::ApiError) do |error|
          expect(error.message).to eq('Rate limit exceeded')
          expect(error.status).to eq(429)
        end
      end
    end
  end

  describe '#send_batch' do
    let(:emails) do
      [
        { from: 'test@example.com', to: 'user1@example.com', subject: 'Hello 1', html: '<p>1</p>' },
        { from: 'test@example.com', to: 'user2@example.com', subject: 'Hello 2', html: '<p>2</p>' }
      ]
    end

    context 'when request is successful' do
      before do
        stub_request(:post, "#{base_url}/emails/batch")
          .to_return(
            status: 200,
            body: { data: [{ id: 'email_1' }, { id: 'email_2' }] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'sends batch and returns response with email ids' do
        response = client.send_batch(emails: emails)
        expect(response['data'].length).to eq(2)
        expect(response['data'][0]['id']).to eq('email_1')
      end
    end

    context 'when batch exceeds 100 emails' do
      let(:large_batch) { Array.new(101) { { from: 'test@example.com', to: 'user@example.com', subject: 'Test', html: '<p>test</p>' } } }

      it 'raises ArgumentError' do
        expect { client.send_batch(emails: large_batch) }.to raise_error(ArgumentError, 'Batch size cannot exceed 100 emails')
      end
    end
  end

  describe '#get_email' do
    let(:email_id) { 'email_12345' }

    context 'when request is successful' do
      before do
        stub_request(:get, "#{base_url}/emails/#{email_id}")
          .to_return(
            status: 200,
            body: { id: email_id, status: 'delivered', to: ['user@example.com'] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns email details' do
        response = client.get_email(email_id: email_id)
        expect(response['id']).to eq(email_id)
        expect(response['status']).to eq('delivered')
      end
    end

    context 'when email not found' do
      before do
        stub_request(:get, "#{base_url}/emails/#{email_id}")
          .to_return(
            status: 404,
            body: { message: 'Email not found' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises ApiError' do
        expect { client.get_email(email_id: email_id) }.to raise_error(Resend::Client::ApiError) do |error|
          expect(error.status).to eq(404)
        end
      end
    end
  end

  describe '#list_domains' do
    before do
      stub_request(:get, "#{base_url}/domains")
        .to_return(
          status: 200,
          body: { data: [{ id: 'domain_1', name: 'example.com' }] }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns list of domains' do
      response = client.list_domains
      expect(response['data']).to be_an(Array)
      expect(response['data'][0]['name']).to eq('example.com')
    end
  end

  describe '#get_domain' do
    let(:domain_id) { 'domain_123' }

    before do
      stub_request(:get, "#{base_url}/domains/#{domain_id}")
        .to_return(
          status: 200,
          body: { id: domain_id, name: 'example.com', status: 'verified' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns domain details' do
      response = client.get_domain(domain_id: domain_id)
      expect(response['id']).to eq(domain_id)
      expect(response['status']).to eq('verified')
    end
  end

  describe '#verify_domain' do
    let(:domain_id) { 'domain_123' }

    before do
      stub_request(:post, "#{base_url}/domains/#{domain_id}/verify")
        .to_return(
          status: 200,
          body: { id: domain_id, status: 'pending' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'initiates domain verification' do
      response = client.verify_domain(domain_id: domain_id)
      expect(response['id']).to eq(domain_id)
    end
  end

  describe '#health_check' do
    context 'when API is reachable' do
      before do
        stub_request(:get, "#{base_url}/domains")
          .to_return(status: 200, body: { data: [] }.to_json)
      end

      it 'returns true' do
        expect(client.health_check).to be true
      end
    end

    context 'when API is unreachable' do
      before do
        stub_request(:get, "#{base_url}/domains")
          .to_timeout
      end

      it 'returns false' do
        expect(client.health_check).to be false
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:get, "#{base_url}/domains")
          .to_return(status: 500, body: { error: 'Internal error' }.to_json)
      end

      it 'returns false' do
        expect(client.health_check).to be false
      end
    end
  end
end
