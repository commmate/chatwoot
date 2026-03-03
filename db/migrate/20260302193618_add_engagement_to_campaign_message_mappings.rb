class AddEngagementToCampaignMessageMappings < ActiveRecord::Migration[7.1]
  def change
    add_column :campaign_message_mappings, :opened_at, :datetime
    add_column :campaign_message_mappings, :clicked_at, :datetime
    add_index :campaign_message_mappings, :opened_at, name: 'idx_campaign_mappings_opened', where: '(opened_at IS NOT NULL)'
    add_index :campaign_message_mappings, :clicked_at, name: 'idx_campaign_mappings_clicked', where: '(clicked_at IS NOT NULL)'
  end
end
