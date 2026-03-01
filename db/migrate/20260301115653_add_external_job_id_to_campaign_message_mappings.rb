class AddExternalJobIdToCampaignMessageMappings < ActiveRecord::Migration[7.1]
  def change
    add_column :campaign_message_mappings, :external_job_id, :string
    add_index :campaign_message_mappings, :external_job_id
  end
end
