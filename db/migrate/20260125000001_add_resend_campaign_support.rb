# frozen_string_literal: true

class AddResendCampaignSupport < ActiveRecord::Migration[7.0]
  def change
    # Track Resend email IDs for delivery status webhooks
    add_column :campaign_message_mappings, :resend_email_id, :string
    add_index :campaign_message_mappings, :resend_email_id, unique: true, where: 'resend_email_id IS NOT NULL'

    # Make whatsapp_message_id nullable to support either WhatsApp or Resend campaigns
    change_column_null :campaign_message_mappings, :whatsapp_message_id, true

    # Update unique index on whatsapp_message_id to only apply when not null
    remove_index :campaign_message_mappings, :whatsapp_message_id
    add_index :campaign_message_mappings, :whatsapp_message_id, unique: true, where: 'whatsapp_message_id IS NOT NULL'

    # Store additional campaign settings (reply-to options, etc.)
    add_column :campaigns, :additional_attributes, :jsonb, default: {}
  end
end

