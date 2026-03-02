class AddReplyTrackingAndSmsSupport < ActiveRecord::Migration[7.0]
  def change
    add_column :campaign_message_mappings, :replied_at, :datetime
    add_column :campaign_message_mappings, :sms_message_id, :string

    add_index :campaign_message_mappings, :replied_at, where: 'replied_at IS NOT NULL',
                                                       name: 'idx_campaign_mappings_replied'
    add_index :campaign_message_mappings, :sms_message_id, unique: true,
                                                           where: 'sms_message_id IS NOT NULL',
                                                           name: 'idx_campaign_mappings_sms_message_id'
    add_index :campaign_message_mappings, %i[contact_id created_at],
              name: 'idx_campaign_mappings_contact_time'
  end
end
