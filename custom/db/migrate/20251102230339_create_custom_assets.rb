# frozen_string_literal: true

class CreateCustomAssets < ActiveRecord::Migration[7.0]
  def change
    create_table :custom_assets do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.string :asset_type, null: false
      t.string :n8n_webhook_url, null: false
      t.string :n8n_workflow_id
      t.text :description
      t.jsonb :display_config, default: { fields: [] }
      t.boolean :enabled, default: true

      t.timestamps
    end

    add_index :custom_assets, [:account_id, :asset_type], name: 'index_custom_assets_on_account_and_type'
    add_index :custom_assets, :enabled
  end
end

