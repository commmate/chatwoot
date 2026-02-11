# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Resend::OneoffCampaignService do
  subject(:campaign_service) { described_class.new(campaign: campaign) }

  let(:account) { create(:account) }
  let(:resend_channel) { create(:channel_email, :resend_email, account: account) }
  let(:resend_inbox) { resend_channel.inbox }
  let(:label1) { create(:label, account: account) }
  let(:label2) { create(:label, account: account) }
  let(:campaign) do
    create(:campaign,
           inbox: resend_inbox,
           account: account,
           audience: [{ type: 'Label', id: label1.id }, { type: 'Label', id: label2.id }],
           additional_attributes: {
             'email_subject' => 'Test Campaign Subject',
             'reply_to_option' => 'resend'
           })
  end

  describe '#perform' do
    context 'when campaign is completed' do
      before { campaign.completed! }

      it 'raises error' do
        expect { campaign_service.perform }.to raise_error('Completed Campaign')
      end
    end

    context 'when campaign is not an email campaign' do
      let(:widget_inbox) { create(:inbox, account: account, channel: create(:channel_widget, account: account)) }
      let(:campaign) { create(:campaign, inbox: widget_inbox, account: account) }

      it 'raises error' do
        expect { campaign_service.perform }.to raise_error(/Invalid campaign/)
      end
    end

    context 'when channel is not Resend provider' do
      let(:imap_channel) { create(:channel_email, :imap_email, account: account) }
      let(:imap_inbox) { imap_channel.inbox }
      let(:campaign) do
        create(:campaign,
               inbox: imap_inbox,
               account: account,
               audience: [{ type: 'Label', id: label1.id }])
      end

      it 'raises error' do
        expect { campaign_service.perform }.to raise_error('Resend provider required')
      end
    end

    context 'when API key is not configured' do
      let(:resend_channel_no_key) do
        create(:channel_email, account: account, provider: 'resend', provider_config: {})
      end
      let(:resend_inbox_no_key) { resend_channel_no_key.inbox }
      let(:campaign) do
        create(:campaign,
               inbox: resend_inbox_no_key,
               account: account,
               audience: [{ type: 'Label', id: label1.id }])
      end

      it 'handles configuration error gracefully' do
        campaign_service.perform

        expect(campaign.reload.completed?).to be true
        expect(campaign.delivery_report).to be_present
        expect(campaign.delivery_report.status).to eq('completed_with_errors')
      end
    end

    context 'when sending to audience contacts' do
      let(:contact1) { create(:contact, account: account, email: 'user1@example.com', name: 'User One') }
      let(:contact2) { create(:contact, account: account, email: 'user2@example.com', name: 'User Two') }
      let(:contact3) { create(:contact, account: account, email: 'user3@example.com', name: 'User Three') }

      before do
        contact1.update_labels([label1.title])
        contact2.update_labels([label2.title])
        contact3.update_labels([label1.title, label2.title])

        stub_request(:post, 'https://api.resend.com/emails')
          .to_return(
            status: 200,
            body: { id: "email_#{SecureRandom.hex(8)}" }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'sends emails to all contacts with labels' do
        campaign_service.perform

        expect(WebMock).to have_requested(:post, 'https://api.resend.com/emails').times(3)
        expect(campaign.reload.completed?).to be true
      end

      it 'creates delivery report with correct counts' do
        campaign_service.perform

        report = campaign.reload.delivery_report
        expect(report).to be_present
        expect(report.total).to eq(3)
        expect(report.succeeded).to eq(3)
        expect(report.failed).to eq(0)
        expect(report.status).to eq('completed')
      end

      it 'creates message mappings for sent emails' do
        campaign_service.perform

        report = campaign.reload.delivery_report
        expect(report.campaign_message_mappings.count).to eq(3)
        expect(report.campaign_message_mappings.pluck(:status).uniq).to eq(['sent'])
      end

      it 'processes Liquid template variables' do
        campaign.update!(message: '<p>Hello {{contact.name}}, welcome!</p>')

        campaign_service.perform

        expect(WebMock).to have_requested(:post, 'https://api.resend.com/emails')
          .with(body: hash_including('html' => include('Hello User One')))
        expect(WebMock).to have_requested(:post, 'https://api.resend.com/emails')
          .with(body: hash_including('html' => include('Hello User Two')))
      end

      it 'uses correct from address' do
        campaign_service.perform

        expect(WebMock).to have_requested(:post, 'https://api.resend.com/emails')
          .with(body: hash_including('from' => 'Test Sender <test@mail.example.com>'))
      end
    end

    context 'when contact has no email' do
      let(:contact_no_email) { create(:contact, account: account, email: nil, name: 'No Email') }
      let(:contact_with_email) { create(:contact, account: account, email: 'valid@example.com', name: 'With Email') }

      before do
        contact_no_email.update_labels([label1.title])
        contact_with_email.update_labels([label1.title])

        stub_request(:post, 'https://api.resend.com/emails')
          .to_return(
            status: 200,
            body: { id: 'email_123' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'skips contacts without email' do
        campaign_service.perform

        expect(WebMock).to have_requested(:post, 'https://api.resend.com/emails').times(1)
      end

      it 'records skip in delivery report' do
        campaign_service.perform

        report = campaign.reload.delivery_report
        expect(report.succeeded).to eq(1)
        expect(report.failed).to eq(1)
      end
    end

    context 'when API returns error for some contacts' do
      let(:contact1) { create(:contact, account: account, email: 'success@example.com', name: 'Success') }
      let(:contact2) { create(:contact, account: account, email: 'fail@example.com', name: 'Fail') }

      before do
        contact1.update_labels([label1.title])
        contact2.update_labels([label1.title])

        # Success for first contact
        stub_request(:post, 'https://api.resend.com/emails')
          .with(body: hash_including('to' => ['success@example.com']))
          .to_return(
            status: 200,
            body: { id: 'email_success' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        # Failure for second contact
        stub_request(:post, 'https://api.resend.com/emails')
          .with(body: hash_including('to' => ['fail@example.com']))
          .to_return(
            status: 422,
            body: { message: 'Invalid email address', name: 'validation_error' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'continues processing after errors' do
        campaign_service.perform

        expect(campaign.reload.completed?).to be true
      end

      it 'records both successes and failures' do
        campaign_service.perform

        report = campaign.reload.delivery_report
        expect(report.succeeded).to eq(1)
        expect(report.failed).to eq(1)
      end

      it 'records error details in report' do
        campaign_service.perform

        report = campaign.reload.delivery_report
        expect(report.errors).to include(hash_including('message' => 'Invalid email address'))
      end
    end

    context 'with different reply-to options' do
      let(:contact) { create(:contact, account: account, email: 'user@example.com', name: 'User') }

      before do
        contact.update_labels([label1.title])

        stub_request(:post, 'https://api.resend.com/emails')
          .to_return(
            status: 200,
            body: { id: 'email_123' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      context 'when reply_to_option is resend' do
        let(:campaign) do
          create(:campaign,
                 inbox: resend_inbox,
                 account: account,
                 audience: [{ type: 'Label', id: label1.id }],
                 additional_attributes: {
                   'email_subject' => 'Test',
                   'reply_to_option' => 'resend'
                 })
        end

        it 'uses Resend from_email as reply-to' do
          campaign_service.perform

          expect(WebMock).to have_requested(:post, 'https://api.resend.com/emails')
            .with(body: hash_including('reply_to' => 'Test Sender <test@mail.example.com>'))
        end
      end

      context 'when reply_to_option is imap' do
        let(:resend_channel_with_imap) do
          create(:channel_email, :resend_email, account: account, imap_enabled: true, imap_login: 'imap@example.com')
        end
        let(:resend_inbox_imap) { resend_channel_with_imap.inbox }
        let(:campaign) do
          create(:campaign,
                 inbox: resend_inbox_imap,
                 account: account,
                 audience: [{ type: 'Label', id: label1.id }],
                 additional_attributes: {
                   'email_subject' => 'Test',
                   'reply_to_option' => 'imap'
                 })
        end

        it 'uses IMAP email as reply-to' do
          campaign_service.perform

          expect(WebMock).to have_requested(:post, 'https://api.resend.com/emails')
            .with(body: hash_including('reply_to' => include('imap@example.com')))
        end
      end

      context 'when reply_to_option is custom' do
        let(:campaign) do
          create(:campaign,
                 inbox: resend_inbox,
                 account: account,
                 audience: [{ type: 'Label', id: label1.id }],
                 additional_attributes: {
                   'email_subject' => 'Test',
                   'reply_to_option' => 'custom',
                   'reply_to_email' => 'custom@example.com'
                 })
        end

        it 'uses custom email as reply-to' do
          campaign_service.perform

          expect(WebMock).to have_requested(:post, 'https://api.resend.com/emails')
            .with(body: hash_including('reply_to' => include('custom@example.com')))
        end
      end

      context 'when from_name is not set' do
        let(:resend_channel_no_name) do
          create(:channel_email, account: account, provider: 'resend', provider_config: {
                   'api_key' => 're_test_key',
                   'from_email' => 'noreply@example.com'
                 })
        end
        let(:resend_inbox_no_name) { resend_channel_no_name.inbox }
        let(:campaign) do
          create(:campaign,
                 inbox: resend_inbox_no_name,
                 account: account,
                 audience: [{ type: 'Label', id: label1.id }],
                 additional_attributes: { 'email_subject' => 'Test' })
        end

        it 'uses only email address for reply-to' do
          campaign_service.perform

          expect(WebMock).to have_requested(:post, 'https://api.resend.com/emails')
            .with(body: hash_including('reply_to' => 'noreply@example.com'))
        end
      end
    end

    context 'with contacts having both labels' do
      let(:contact) { create(:contact, account: account, email: 'user@example.com', name: 'User') }

      before do
        contact.update_labels([label1.title, label2.title])

        stub_request(:post, 'https://api.resend.com/emails')
          .to_return(
            status: 200,
            body: { id: 'email_123' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'sends only one email per contact' do
        campaign_service.perform

        expect(WebMock).to have_requested(:post, 'https://api.resend.com/emails').times(1)
      end
    end
  end
end
