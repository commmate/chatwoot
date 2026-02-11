# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CampaignMessageMapping, type: :model do
  let(:account) { create(:account) }
  let(:resend_channel) { create(:channel_email, :resend_email, account: account) }
  let(:inbox) { resend_channel.inbox }
  let(:contact) { create(:contact, account: account, email: 'user@example.com') }
  let(:campaign) { create(:campaign, inbox: inbox, account: account) }
  let(:delivery_report) do
    CampaignDeliveryReport.create!(
      campaign: campaign,
      provider: 'resend',
      status: 'completed',
      total: 10,
      succeeded: 10,
      failed: 0
    )
  end

  describe 'validations' do
    context 'with resend_email_id' do
      it 'is valid with resend_email_id' do
        mapping = described_class.new(
          campaign_delivery_report: delivery_report,
          contact: contact,
          resend_email_id: 'email_123',
          status: 'sent'
        )
        expect(mapping).to be_valid
      end

      it 'enforces uniqueness of resend_email_id' do
        described_class.create!(
          campaign_delivery_report: delivery_report,
          contact: contact,
          resend_email_id: 'email_unique',
          status: 'sent'
        )

        duplicate = described_class.new(
          campaign_delivery_report: delivery_report,
          contact: create(:contact, account: account, email: 'other@example.com'),
          resend_email_id: 'email_unique',
          status: 'sent'
        )

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:resend_email_id]).to include('has already been taken')
      end
    end

    context 'with whatsapp_message_id' do
      it 'is valid with whatsapp_message_id' do
        mapping = described_class.new(
          campaign_delivery_report: delivery_report,
          contact: contact,
          whatsapp_message_id: 'wamid_123',
          status: 'sent'
        )
        expect(mapping).to be_valid
      end
    end

    context 'without external id' do
      it 'is invalid without either resend_email_id or whatsapp_message_id' do
        mapping = described_class.new(
          campaign_delivery_report: delivery_report,
          contact: contact,
          status: 'sent'
        )
        expect(mapping).not_to be_valid
        expect(mapping.errors[:base]).to include('Either whatsapp_message_id or resend_email_id must be present')
      end
    end

    it 'requires status' do
      mapping = described_class.new(
        campaign_delivery_report: delivery_report,
        contact: contact,
        resend_email_id: 'email_123',
        status: nil
      )
      expect(mapping).not_to be_valid
    end
  end

  describe '#update_from_webhook' do
    let!(:mapping) do
      described_class.create!(
        campaign_delivery_report: delivery_report,
        contact: contact,
        resend_email_id: 'email_webhook_test',
        status: 'sent'
      )
    end

    context 'when updating to delivered' do
      it 'updates status to delivered' do
        mapping.update_from_webhook(status: 'delivered')
        expect(mapping.reload.status).to eq('delivered')
      end
    end

    context 'when updating to failed' do
      let(:errors) do
        [{ code: 'BOUNCED', title: 'Mailbox not found' }]
      end

      it 'updates status to failed' do
        mapping.update_from_webhook(status: 'failed', errors: errors)
        expect(mapping.reload.status).to eq('failed')
      end

      it 'extracts error code from webhook errors' do
        mapping.update_from_webhook(status: 'failed', errors: errors)
        expect(mapping.reload.error_code).to eq('BOUNCED')
      end

      it 'extracts error message from webhook errors' do
        mapping.update_from_webhook(status: 'failed', errors: errors)
        expect(mapping.reload.error_message).to eq('Mailbox not found')
      end

      it 'syncs failure to delivery report' do
        expect { mapping.update_from_webhook(status: 'failed', errors: errors) }
          .to change { delivery_report.reload.failed }.from(0).to(1)
      end

      it 'decrements succeeded count on report' do
        expect { mapping.update_from_webhook(status: 'failed', errors: errors) }
          .to change { delivery_report.reload.succeeded }.from(10).to(9)
      end

      it 'updates report status to completed_with_errors' do
        mapping.update_from_webhook(status: 'failed', errors: errors)
        expect(delivery_report.reload.status).to eq('completed_with_errors')
      end

      it 'records error on delivery report' do
        mapping.update_from_webhook(status: 'failed', errors: errors)
        expect(delivery_report.reload.delivery_errors).to include(
          hash_including('code' => 'BOUNCED', 'message' => 'Mailbox not found')
        )
      end
    end

    context 'when already failed' do
      before do
        mapping.update!(status: 'failed', error_code: 'INITIAL_ERROR')
      end

      it 'does not double-count failures' do
        delivery_report.update!(failed: 1)

        mapping.update_from_webhook(status: 'failed', errors: [{ code: 'ANOTHER_ERROR', title: 'Another error' }])

        expect(delivery_report.reload.failed).to eq(1)
      end
    end

    context 'with string-keyed errors' do
      let(:errors) do
        [{ 'code' => 'SPAM', 'title' => 'Marked as spam' }]
      end

      it 'handles string keys' do
        mapping.update_from_webhook(status: 'failed', errors: errors)
        expect(mapping.reload.error_code).to eq('SPAM')
        expect(mapping.reload.error_message).to eq('Marked as spam')
      end
    end

    context 'with error_data details' do
      let(:errors) do
        [{
          code: 'BOUNCED',
          title: 'Hard bounce',
          error_data: { details: 'smtp;550 5.1.1 User unknown' }
        }]
      end

      it 'extracts error details' do
        mapping.update_from_webhook(status: 'failed', errors: errors)
        expect(mapping.reload.error_details).to eq('smtp;550 5.1.1 User unknown')
      end
    end
  end

  describe 'associations' do
    it 'belongs to campaign_delivery_report' do
      mapping = described_class.new(
        campaign_delivery_report: delivery_report,
        contact: contact,
        resend_email_id: 'email_assoc',
        status: 'sent'
      )
      expect(mapping.campaign_delivery_report).to eq(delivery_report)
    end

    it 'belongs to contact' do
      mapping = described_class.new(
        campaign_delivery_report: delivery_report,
        contact: contact,
        resend_email_id: 'email_contact',
        status: 'sent'
      )
      expect(mapping.contact).to eq(contact)
    end
  end
end
