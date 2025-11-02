# frozen_string_literal: true

module CustomAssets
  # Service to format asset data for WhatsApp messages
  # Supports both simple text formatting and OpenAI-powered formatting
  class MessageFormatterService
    def initialize(custom_asset)
      @asset = custom_asset
    end

    def format(asset_data)
      if openai_integration_available?
        format_with_llm(asset_data)
      else
        format_as_text(asset_data)
      end
    end

    private

    def format_as_text(asset_data)
      lines = ["*#{@asset.name}*", '']

      @asset.display_fields.each do |field|
        value = asset_data[field['key']]
        next if value.blank?

        formatted_value = format_field_value(value, field['type'], field['format'])
        lines << "#{field['label']}: #{formatted_value}"
      end

      lines.join("\n")
    end

    def format_with_llm(asset_data)
      # Use OpenAI integration to format naturally
      hook = @asset.account.hooks.find_by(app_id: 'openai', status: 'enabled')
      return format_as_text(asset_data) if hook.blank?

      # For now, fall back to text formatting
      # TODO: Implement OpenAI formatting with Integrations::Openai::ProcessorService
      format_as_text(asset_data)
    end

    def format_field_value(value, type, format)
      case type
      when 'currency'
        format_currency(value, format)
      when 'date'
        format_date(value, format)
      when 'link'
        value
      else
        value.to_s
      end
    rescue StandardError => e
      Rails.logger.warn("Failed to format value: #{e.message}")
      value.to_s
    end

    def format_currency(value, currency_code)
      # Simple currency formatting
      currency = currency_code || 'USD'
      "#{currency} #{format('%.2f', value.to_f)}"
    end

    def format_date(value, date_format)
      Date.parse(value.to_s).strftime(date_format || '%Y-%m-%d')
    rescue StandardError
      value.to_s
    end

    def openai_integration_available?
      @asset.account.hooks.exists?(app_id: 'openai', status: 'enabled')
    end
  end
end

