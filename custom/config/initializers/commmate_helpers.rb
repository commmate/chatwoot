# frozen_string_literal: true

# Ensure CommMate helpers are available to views
# Rails automatically includes helpers from app/helpers/, and since we've added
# custom/app/helpers to autoload paths, helpers should be automatically available.
# This initializer ensures the helper is loaded and available.
Rails.application.config.to_prepare do
  # Helpers are automatically included by Rails from app/helpers/ directories
  # Since custom/app/helpers is in autoload paths, CommmateBrandingHelper
  # will be automatically available in views
end
