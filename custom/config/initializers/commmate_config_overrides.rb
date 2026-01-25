# frozen_string_literal: true

# CommMate Configuration Overrides
# This initializer runs AFTER the default ConfigLoader
# and overrides only CommMate-specific configs (branding, privacy)

module CommMateConfigOverrides
  CHATWOOT_DEFAULTS = {
    'INSTALLATION_NAME' => 'Chatwoot',
    'BRAND_NAME' => 'Chatwoot',
    'BRAND_URL' => 'https://www.chatwoot.com',
    'WIDGET_BRAND_URL' => 'https://www.chatwoot.com',
    'TERMS_URL' => 'https://www.chatwoot.com/terms-of-service',
    'PRIVACY_URL' => 'https://www.chatwoot.com/privacy-policy',
    'LOGO' => '/brand-assets/logo.svg',
    'LOGO_DARK' => '/brand-assets/logo_dark.svg',
    'LOGO_THUMBNAIL' => '/brand-assets/logo_thumbnail.svg',
    'DEFAULT_LOCALE' => 'en'
  }.freeze

  class << self
    def apply_overrides
      return unless database_ready?

      commmate_config_path = Rails.root.join('custom/config/installation_config.yml')
      return unless File.exist?(commmate_config_path)

      Rails.logger.info '🎨 Applying CommMate config overrides...'
      configs = YAML.safe_load(File.read(commmate_config_path))
      configs.each { |config| apply_config(config.with_indifferent_access) }
      GlobalConfig.clear_cache
      Rails.logger.info '✅ CommMate config overrides applied'
    rescue StandardError => e
      Rails.logger&.debug { "CommMate config overrides skipped: #{e.message}" }
    end

    private

    def database_ready?
      ActiveRecord::Base.connection.active? &&
        ActiveRecord::Base.connection.table_exists?('installation_configs')
    end

    def apply_config(config)
      existing = InstallationConfig.find_by(name: config[:name])

      if existing
        override_if_default(existing, config)
      else
        create_config(config)
      end
    end

    def override_if_default(existing, config)
      return unless existing.value == CHATWOOT_DEFAULTS[config[:name]]

      existing.update!(value: config[:value])
      Rails.logger.info "  ✓ Overrode #{config[:name]}: #{config[:value]}"
    end

    def create_config(config)
      InstallationConfig.create!(
        name: config[:name],
        value: config[:value],
        locked: config[:locked] || false
      )
      Rails.logger.info "  ✓ Created #{config[:name]}: #{config[:value]}"
    end
  end
end

Rails.application.config.after_initialize do
  CommMateConfigOverrides.apply_overrides
end
