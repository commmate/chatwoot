# frozen_string_literal: true

class CreatePipelines < ActiveRecord::Migration[7.1]
  def change
    create_table :pipelines do |t|
      t.string :name, null: false
      t.text :description
      t.jsonb :stages, default: []
      t.references :account, null: false, foreign_key: true
      t.bigint :custom_attribute_definition_id
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :pipelines, [:account_id, :name], unique: true
    add_index :pipelines, :custom_attribute_definition_id
  end
end

