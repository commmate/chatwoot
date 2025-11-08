# frozen_string_literal: true

module CustomAssets
  # Service to interact with n8n workflows for fetching external asset data
  class N8nClientService
    def initialize(custom_asset)
      @asset = custom_asset
    end

    def fetch_list(contact, options = {})
      response = HTTParty.post(
        @asset.n8n_webhook_url,
        body: build_payload(contact, options).to_json,
        headers: { 'Content-Type' => 'application/json' },
        timeout: 30
      )

      return [] unless response.success?

      parse_response(response.parsed_response)
    rescue StandardError => e
      Rails.logger.error("n8n fetch failed for #{@asset.name}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      []
    end

    private

    def build_payload(contact, options)
      {
        contact_id: contact.id,
        email: contact.email,
        phone: contact.phone_number,
        name: contact.name,
        custom_attributes: contact.custom_attributes,
        additional_attributes: contact.additional_attributes,
        search_query: options[:search],
        filters: options[:filters] || {},
        account_id: @asset.account_id
      }
    end

    def parse_response(response)
      # n8n can return array directly or { items: [...] } or { data: [...] } or { results: [...] }
      case response
      when Array
        response
      when Hash
        response['items'] || response['data'] || response['results'] || []
      else
        []
      end
    end
  end
end


