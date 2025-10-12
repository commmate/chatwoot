# frozen_string_literal: true

# == Schema Information
#
# Table name: pipelines
#
#  id                              :bigint           not null, primary key
#  name                            :string           not null
#  description                     :text
#  stages                          :jsonb            default([])
#  account_id                      :bigint           not null
#  custom_attribute_definition_id  :bigint
#  position                        :integer          default(0)
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#

class Pipeline < ApplicationRecord
  belongs_to :account
  belongs_to :custom_attribute_definition, optional: true

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :stages, presence: true
  validate :stages_must_be_valid_array

  before_create :create_custom_attribute
  after_update :sync_custom_attribute_values, if: :saved_change_to_stages?
  before_destroy :cleanup_custom_attribute

  scope :ordered, -> { order(position: :asc, created_at: :asc) }

  def stage_names
    stages.map { |s| s['name'] }
  end

  def custom_field_key
    "pipeline_#{id}_stage"
  end

  def conversations_count
    return 0 unless custom_attribute_definition_id

    account.conversations
           .where("custom_attributes ? :key", key: custom_field_key)
           .count
  end

  private

  def stages_must_be_valid_array
    return errors.add(:stages, 'must be an array') unless stages.is_a?(Array)
    return errors.add(:stages, 'must have at least one stage') if stages.empty?

    stages.each_with_index do |stage, index|
      errors.add(:stages, "stage #{index} must have a name") unless stage.is_a?(Hash) && stage['name'].present?
    end
  end

  def create_custom_attribute
    # Generate unique key for this pipeline
    attribute_key = "pipeline_#{name.parameterize.underscore}_stage"
    
    # Ensure uniqueness
    base_key = attribute_key
    counter = 1
    while CustomAttributeDefinition.exists?(account_id: account_id, attribute_key: attribute_key)
      attribute_key = "#{base_key}_#{counter}"
      counter += 1
    end

    # Create the custom attribute definition
    custom_attr = account.custom_attribute_definitions.create!(
      attribute_display_name: "#{name} - Stage",
      attribute_key: attribute_key,
      attribute_model: :conversation_attribute,
      attribute_display_type: :list,
      attribute_values: stage_names,
      attribute_description: "Pipeline stages for #{name}"
    )

    self.custom_attribute_definition_id = custom_attr.id
  end

  def sync_custom_attribute_values
    return unless custom_attribute_definition

    # Update the custom attribute definition with new stage names
    custom_attribute_definition.update!(
      attribute_values: stage_names,
      attribute_description: "Pipeline stages for #{name}"
    )
  end

  def cleanup_custom_attribute
    return unless custom_attribute_definition

    # Get the custom field key
    field_key = custom_attribute_definition.attribute_key

    # Clear the custom attribute from all conversations
    account.conversations
           .where("custom_attributes ? :key", key: field_key)
           .find_each do |conversation|
      conversation.custom_attributes.delete(field_key)
      conversation.save
    end

    # Delete the custom attribute definition
    custom_attribute_definition.destroy
  end
end

