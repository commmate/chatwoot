# frozen_string_literal: true

# Include CommMate branding helper in super admin controllers
module CommmateBrandingControllerConcern
  extend ActiveSupport::Concern

  included do
    helper CommmateBrandingHelper
  end
end
