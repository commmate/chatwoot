# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webhooks::ResendEventsJob, type: :job do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:resend_channel) { create(:channel_email, :resend_email, account: account) }
  let(:inbox) { resend_channel.inbox }

  describe '#perform' do
    context 'when inbox is not found' do
      it 'does not process event' do
        expect(Resend::DeliveryStatusService).not_to receive(:new)

        described_class.new.perform(inbox_id: 0, payload: { type: 'email.delivered' })
      end
    end

    context 'when inbox is not an email channel' do
      let(:widget_channel) { create(:channel_widget, account: account) }
      let(:widget_inbox) { create(:inbox, channel: widget_channel, account: account) }

      it 'does not process event' do
        expect(Resend::DeliveryStatusService).not_to receive(:new)

        described_class.new.perform(inbox_id: widget_inbox.id, payload: { type: 'email.delivered' })
      end
    end

    context 'when inbox channel is not Resend provider' do
      let(:imap_channel) { create(:channel_email, :imap_email, account: account) }
      let(:imap_inbox) { imap_channel.inbox }

      it 'does not process event' do
        expect(Resend::DeliveryStatusService).not_to receive(:new)

        described_class.new.perform(inbox_id: imap_inbox.id, payload: { type: 'email.delivered' })
      end
    end

    context 'when processing delivery status events' do
      let(:delivery_status_events) do
        %w[email.sent email.delivered email.bounced email.failed email.delivery_delayed email.complained]
      end

      it 'calls DeliveryStatusService for each event type' do
        delivery_status_events.each do |event_type|
          payload = { type: event_type, data: { email_id: 'email_123' } }
          service = instance_double(Resend::DeliveryStatusService)

          expect(Resend::DeliveryStatusService).to receive(:new)
            .with(inbox: inbox, payload: hash_including(type: event_type))
            .and_return(service)
          expect(service).to receive(:perform)

          described_class.new.perform(inbox_id: inbox.id, payload: payload)
        end
      end
    end

    context 'when processing engagement events' do
      %w[email.opened email.clicked].each do |event_type|
        it "calls DeliveryStatusService for #{event_type}" do
          payload = { type: event_type, data: { email_id: 'email_123' } }
          service = instance_double(Resend::DeliveryStatusService)

          expect(Resend::DeliveryStatusService).to receive(:new)
            .with(inbox: inbox, payload: hash_including(type: event_type))
            .and_return(service)
          expect(service).to receive(:perform)

          described_class.new.perform(inbox_id: inbox.id, payload: payload)
        end
      end
    end

    context 'when processing inbound email event' do
      let(:payload) do
        {
          type: 'email.received',
          data: {
            email_id: 'email_inbound',
            from: 'sender@example.com',
            to: [resend_channel.email],
            subject: 'Inbound Test',
            html: '<p>Hello</p>'
          }
        }
      end

      it 'calls InboundEmailService' do
        service = instance_double(Resend::InboundEmailService)

        expect(Resend::InboundEmailService).to receive(:new)
          .with(inbox: inbox, payload: hash_including(type: 'email.received'))
          .and_return(service)
        expect(service).to receive(:perform)

        described_class.new.perform(inbox_id: inbox.id, payload: payload)
      end
    end

    context 'when processing unknown event type' do
      it 'logs a warning and does not call any service' do
        payload = { type: 'unknown.event', data: {} }

        expect(Resend::DeliveryStatusService).not_to receive(:new)
        expect(Resend::InboundEmailService).not_to receive(:new)
        expect(Rails.logger).to receive(:warn).with(/Unknown event type/)

        described_class.new.perform(inbox_id: inbox.id, payload: payload)
      end
    end

    context 'when service raises an error' do
      it 'logs the error and re-raises' do
        payload = { type: 'email.delivered', data: { email_id: 'email_123' } }
        service = instance_double(Resend::DeliveryStatusService)

        expect(Resend::DeliveryStatusService).to receive(:new).and_return(service)
        expect(service).to receive(:perform).and_raise(StandardError, 'Test error')
        expect(Rails.logger).to receive(:error).at_least(:once)

        expect do
          described_class.new.perform(inbox_id: inbox.id, payload: payload)
        end.to raise_error(StandardError, 'Test error')
      end
    end

    context 'with payload as string keys' do
      it 'handles string-keyed payload correctly' do
        payload = { 'type' => 'email.delivered', 'data' => { 'email_id' => 'email_123' } }
        service = instance_double(Resend::DeliveryStatusService)

        expect(Resend::DeliveryStatusService).to receive(:new)
          .with(inbox: inbox, payload: hash_including('type' => 'email.delivered'))
          .and_return(service)
        expect(service).to receive(:perform)

        described_class.new.perform(inbox_id: inbox.id, payload: payload)
      end
    end
  end

  describe 'job configuration' do
    it 'is queued in the default queue' do
      expect(described_class.new.queue_name).to eq('default')
    end

    it 'can be enqueued' do
      expect do
        described_class.perform_later(inbox_id: inbox.id, payload: { type: 'email.sent' })
      end.to have_enqueued_job(described_class)
        .with(inbox_id: inbox.id, payload: { type: 'email.sent' })
        .on_queue('default')
    end
  end
end
