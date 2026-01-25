# frozen_string_literal: true

# CommMate branding rake tasks
module CommMateBrandingHelper
  BRANDING_CONFIG = {
    'INSTALLATION_NAME' => 'CommMate',
    'BRAND_NAME' => 'CommMate',
    'BRAND_URL' => 'https://commmate.com',
    'WIDGET_BRAND_URL' => 'https://commmate.com',
    'TERMS_URL' => 'https://commmate.com/terms',
    'PRIVACY_URL' => 'https://commmate.com/privacy',
    'LOGO' => '/brand-assets/logo-full.png',
    'LOGO_DARK' => '/brand-assets/logo-full-dark.png',
    'LOGO_THUMBNAIL' => '/brand-assets/logo_thumbnail.png'
  }.freeze

  VERIFY_KEYS = %w[
    INSTALLATION_NAME BRAND_NAME BRAND_URL
    LOGO LOGO_DARK LOGO_THUMBNAIL
  ].freeze

  class << self
    def apply_branding
      BRANDING_CONFIG.each do |name, value|
        InstallationConfig.find_or_create_by!(name: name).update!(value: value)
      end
      InstallationConfig.where(name: 'IS_ENTERPRISE').delete_all
    end

    def verify_branding
      VERIFY_KEYS.each { |key| verify_config(key) }
      verify_enterprise_disabled
    end

    private

    def verify_config(name)
      value = InstallationConfig.find_by(name: name)&.value
      status = commmate_branded?(value) ? '✅' : '❌'
      puts "#{status} #{name.titleize}: #{value || 'NOT SET'}"
    end

    def commmate_branded?(value)
      value&.include?('CommMate') || value&.include?('commmate') || value&.include?('brand-assets')
    end

    def verify_enterprise_disabled
      is_enterprise = InstallationConfig.exists?(name: 'IS_ENTERPRISE')
      status = is_enterprise ? '❌' : '✅'
      message = is_enterprise ? 'ENABLED (should be disabled)' : 'Disabled'
      puts "#{status} SSO/Enterprise: #{message}"
    end
  end
end

namespace :commmate do
  desc 'Apply CommMate branding to database'
  task branding: :environment do
    puts '🎨 Applying CommMate branding...'
    CommMateBrandingHelper.apply_branding
    puts '✅ CommMate branding applied successfully!'
  rescue StandardError => e
    puts "❌ Error applying CommMate branding: #{e.message}"
    raise
  end

  desc 'Verify CommMate branding configuration'
  task verify: :environment do
    puts '🔍 Verifying CommMate branding...'
    CommMateBrandingHelper.verify_branding
  end
end
