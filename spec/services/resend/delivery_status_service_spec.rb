# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Resend::DeliveryStatusService do
  subject(:service) { described_class.new(inbox: inbox, payload: payload) }

  let(:account) { create(:account) }
  let(:resend_channel) { create(:channel_email, :resend_email, account: account) }
  let(:inbox) { resend_channel.inbox }
  let(:contact) { create(:contact, account: account, email: 'user@example.com') }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: 'user@example.com') }
  let(:conversation) { create(:conversation, contact: contact, inbox: inbox, contact_inbox: contact_inbox, account: account) }
  let(:email_id) { 'email_12345' }

  describe '#perform' do
    context 'when email_id is blank' do
      let(:payload) { { type: 'email.delivered', data: {} } }

      it 'does nothing' do
        expect { service.perform }.not_to raise_error
      end
    end

    context 'when processing email.sent event' do
      let!(:message) do
        # Use sent status as initial state (simulating a message that was just sent)
        create(:message, account: account, inbox: inbox, conversation: conversation,
                         status: :sent, source_id: email_id)
      end
      let(:payload) { { type: 'email.sent', data: { email_id: email_id } } }

      it 'keeps message status as sent' do
        service.perform
        expect(message.reload.status).to eq('sent')
      end
    end

    context 'when processing email.delivered event' do
      let!(:message) do
        create(:message, account: account, inbox: inbox, conversation: conversation,
                         status: :sent, source_id: email_id)
      end
      let(:payload) { { type: 'email.delivered', data: { email_id: email_id } } }

      it 'updates message status to delivered' do
        service.perform
        expect(message.reload.status).to eq('delivered')
      end
    end

    context 'when processing email.bounced event' do
      let!(:message) do
        create(:message, account: account, inbox: inbox, conversation: conversation,
                         status: :sent, source_id: email_id)
      end
      let(:payload) do
        {
          type: 'email.bounced',
          data: {
            email_id: email_id,
            bounce: { message: 'Mailbox not found' }
          }
        }
      end

      it 'updates message status to failed' do
        service.perform
        expect(message.reload.status).to eq('failed')
      end

      it 'sets external_error with bounce message' do
        service.perform
        expect(message.reload.external_error).to eq('Bounced: Mailbox not found')
      end
    end

    context 'when processing email.failed event' do
      let!(:message) do
        create(:message, account: account, inbox: inbox, conversation: conversation,
                         status: :sent, source_id: email_id)
      end
      let(:payload) do
        {
          type: 'email.failed',
          data: {
            email_id: email_id,
            error: 'Domain not verified'
          }
        }
      end

      it 'updates message status to failed' do
        service.perform
        expect(message.reload.status).to eq('failed')
      end

      it 'sets external_error with error message' do
        service.perform
        expect(message.reload.external_error).to eq('Failed: Domain not verified')
      end
    end

    context 'when processing email.delivery_delayed event' do
      let!(:message) do
        create(:message, account: account, inbox: inbox, conversation: conversation,
                         status: :sent, source_id: email_id)
      end
      let(:payload) { { type: 'email.delivery_delayed', data: { email_id: email_id } } }

      it 'keeps message status as sent' do
        service.perform
        expect(message.reload.status).to eq('sent')
      end
    end

    context 'when processing email.complained event' do
      let!(:message) do
        create(:message, account: account, inbox: inbox, conversation: conversation,
                         status: :delivered, source_id: email_id)
      end
      let(:payload) { { type: 'email.complained', data: { email_id: email_id } } }

      it 'updates message status to failed' do
        service.perform
        expect(message.reload.status).to eq('failed')
      end

      it 'sets external_error indicating spam complaint' do
        service.perform
        expect(message.reload.external_error).to eq('Marked as spam by recipient')
      end
    end

    context 'when processing email.opened event' do
      let!(:message) do
        create(:message, account: account, inbox: inbox, conversation: conversation,
                         status: :delivered, source_id: email_id)
      end
      let(:payload) { { type: 'email.opened', data: { email_id: email_id } } }

      it 'tracks opened engagement in additional_attributes' do
        service.perform

        message.reload
        expect(message.additional_attributes['resend_engagement']['opened']).to be_present
      end
    end

    context 'when processing email.clicked event' do
      let!(:message) do
        create(:message, account: account, inbox: inbox, conversation: conversation,
                         status: :delivered, source_id: email_id,
                         additional_attributes: { 'resend_engagement' => { 'opened' => Time.current.iso8601 } })
      end
      let(:payload) { { type: 'email.clicked', data: { email_id: email_id } } }

      it 'tracks clicked engagement in additional_attributes' do
        service.perform

        message.reload
        expect(message.additional_attributes['resend_engagement']['clicked']).to be_present
        expect(message.additional_attributes['resend_engagement']['opened']).to be_present
      end
    end

    context 'when message is not found' do
      let(:payload) { { type: 'email.delivered', data: { email_id: 'unknown_email_id' } } }

      it 'does not raise error' do
        expect { service.perform }.not_to raise_error
      end
    end

    context 'when updating campaign message mapping' do
      let(:campaign) { create(:campaign, inbox: inbox, account: account) }
      let(:delivery_report) { create(:campaign_delivery_report, campaign: campaign) }
      let!(:campaign_mapping) do
        CampaignMessageMapping.create!(
          campaign_delivery_report: delivery_report,
          contact: contact,
          resend_email_id: email_id,
          status: 'sent'
        )
      end
      let(:payload) { { type: 'email.delivered', data: { email_id: email_id } } }

      it 'updates campaign mapping status to delivered' do
        service.perform
        expect(campaign_mapping.reload.status).to eq('delivered')
      end

      context 'when email bounced' do
        let(:payload) do
          {
            type: 'email.bounced',
            data: {
              email_id: email_id,
              bounce: { message: 'User unknown' }
            }
          }
        end

        it 'updates mapping status to failed' do
          service.perform
          expect(campaign_mapping.reload.status).to eq('failed')
        end

        it 'records error on mapping' do
          service.perform

          campaign_mapping.reload
          expect(campaign_mapping.error_code).to eq('BOUNCED')
          expect(campaign_mapping.error_message).to eq('User unknown')
        end

        it 'syncs failure to delivery report' do
          service.perform

          delivery_report.reload
          expect(delivery_report.failed).to eq(1)
          expect(delivery_report.status).to eq('completed_with_errors')
        end
      end

      context 'when email complained (spam)' do
        let(:payload) { { type: 'email.complained', data: { email_id: email_id } } }

        it 'updates mapping with spam error' do
          service.perform

          campaign_mapping.reload
          expect(campaign_mapping.status).to eq('failed')
          expect(campaign_mapping.error_code).to eq('SPAM')
          expect(campaign_mapping.error_message).to eq('Marked as spam by recipient')
        end
      end
    end

    context 'when both message and campaign mapping exist' do
      let!(:message) do
        create(:message, account: account, inbox: inbox, conversation: conversation,
                         status: :sent, source_id: email_id)
      end
      let(:campaign) { create(:campaign, inbox: inbox, account: account) }
      let(:delivery_report) { create(:campaign_delivery_report, campaign: campaign) }
      let!(:campaign_mapping) do
        CampaignMessageMapping.create!(
          campaign_delivery_report: delivery_report,
          contact: contact,
          resend_email_id: email_id,
          status: 'sent'
        )
      end
      let(:payload) { { type: 'email.delivered', data: { email_id: email_id } } }

      it 'updates both message and campaign mapping' do
        service.perform

        expect(message.reload.status).to eq('delivered')
        expect(campaign_mapping.reload.status).to eq('delivered')
      end
    end
  end
end
