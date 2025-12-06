# frozen_string_literal: true

# CommMate Branding Helper
# Provides centralized branding configuration for views
module CommmateBrandingHelper
  def admin_console_name
    'CommMate Admin Console'
  end

  def admin_console_logo_path
    '/brand-assets/logo_thumbnail.png'
  end

  def admin_console_version
    defined?(COMMMATE_VERSION) ? COMMMATE_VERSION : Chatwoot.config[:version]
  end

  def admin_login_logo_light
    '/brand-assets/logo-full.png'
  end

  def admin_login_logo_dark
    '/brand-assets/logo-full-dark.png'
  end

  def admin_login_title
    'SuperAdmin | CommMate'
  end
end
