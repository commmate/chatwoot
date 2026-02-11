# frozen_string_literal: true

class AddResendCampaignSupport < ActiveRecord::Migration[7.0]
  def change
    # Track Resend email IDs for delivery status webhooks
    add_column :campaign_message_mappings, :resend_email_id, :string unless column_exists?(:campaign_message_mappings, :resend_email_id)
    unless index_exists?(:campaign_message_mappings, :resend_email_id)
      add_index :campaign_message_mappings, :resend_email_id, unique: true, where: 'resend_email_id IS NOT NULL'
    end

    # Make whatsapp_message_id nullable to support either WhatsApp or Resend campaigns
    change_column_null :campaign_message_mappings, :whatsapp_message_id, true

    # Update unique index on whatsapp_message_id to only apply when not null (only if index exists)
    remove_index :campaign_message_mappings, :whatsapp_message_id if index_exists?(:campaign_message_mappings, :whatsapp_message_id)
    unless index_exists?(:campaign_message_mappings, :whatsapp_message_id)
      add_index :campaign_message_mappings, :whatsapp_message_id, unique: true, where: 'whatsapp_message_id IS NOT NULL'
    end

    # Store additional campaign settings (reply-to options, etc.)
    add_column :campaigns, :additional_attributes, :jsonb, default: {} unless column_exists?(:campaigns, :additional_attributes)

    # Ensure campaign display_id triggers and sequences exist
    # This is needed because the triggers from init_schema may not exist in dev/test environments
    ensure_campaign_triggers_and_sequences
  end

  private

  def ensure_campaign_triggers_and_sequences # rubocop:disable Metrics/MethodLength
    # 1. Create function and trigger for auto-creating sequences when accounts are created
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION camp_dpid_before_insert()
      RETURNS TRIGGER AS $$
      BEGIN
        execute format('create sequence IF NOT EXISTS camp_dpid_seq_%s', NEW.id);
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS camp_dpid_before_insert ON accounts;
      CREATE TRIGGER camp_dpid_before_insert
      AFTER INSERT ON accounts
      FOR EACH ROW
      EXECUTE FUNCTION camp_dpid_before_insert();
    SQL

    # 2. Create function and trigger for setting campaign display_id
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION campaigns_before_insert_row_tr()
      RETURNS TRIGGER AS $$
      BEGIN
        NEW.display_id := nextval('camp_dpid_seq_' || NEW.account_id);
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS campaigns_before_insert_row_tr ON campaigns;
      CREATE TRIGGER campaigns_before_insert_row_tr
      BEFORE INSERT ON campaigns
      FOR EACH ROW
      EXECUTE FUNCTION campaigns_before_insert_row_tr();
    SQL

    # 3. Create sequences for all existing accounts that don't have them
    Account.find_each do |account|
      execute "CREATE SEQUENCE IF NOT EXISTS camp_dpid_seq_#{account.id};"
    end
  end
end
