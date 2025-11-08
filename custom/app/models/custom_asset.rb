# frozen_string_literal: true

# CustomAsset model for n8n-powered external asset integration
# Each asset represents a configured n8n workflow that fetches data from external APIs
class CustomAsset < ApplicationRecord
  belongs_to :account

  validates :name, presence: true
  validates :asset_type, presence: true
  validates :n8n_webhook_url, presence: true, format: URI::DEFAULT_PARSER.make_regexp(%w[http https])

  scope :enabled, -> { where(enabled: true) }

  # Returns the n8n workflow editor link if workflow_id is present
  def n8n_workflow_link
    return nil if n8n_workflow_id.blank?

    "#{ENV.fetch('N8N_URL', 'http://localhost:5678')}/workflow/#{n8n_workflow_id}"
  end

  # Returns display fields configuration
  def display_fields
    display_config&.dig('fields') || []
  end
end


