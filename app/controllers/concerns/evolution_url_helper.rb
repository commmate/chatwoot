# frozen_string_literal: true

# Shared helper for Evolution API URL handling
module EvolutionUrlHelper
  extend ActiveSupport::Concern

  # Returns a Chatwoot URL reachable by Evolution API
  # In development with containerized Evolution, we need the host IP
  def chatwoot_reachable_url
    return production_frontend_url unless Rails.env.development?

    development_frontend_url
  end

  private

  def production_frontend_url
    ENV.fetch('FRONTEND_URL', nil) || Rails.application.routes.url_helpers.root_url
  end

  def development_frontend_url
    frontend_url = ENV.fetch('FRONTEND_URL', nil)
    return frontend_url unless localhost_url?(frontend_url)

    "http://#{development_host_ip}:3000"
  end

  def localhost_url?(url)
    url&.include?('localhost') || url&.include?('127.0.0.1')
  end

  def development_host_ip
    host_ip = `ipconfig getifaddr en0 2>/dev/null`.strip
    host_ip.presence || '192.168.0.22'
  end
end
