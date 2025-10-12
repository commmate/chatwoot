# frozen_string_literal: true

# Load Custom module namespace before other initializers
require_relative '../../lib/custom'

# Autoload Custom modules
Rails.application.config.to_prepare do
  # Custom modules will be loaded automatically via Zeitwerk
  # This ensures the Custom:: namespace is available for extensions
end

