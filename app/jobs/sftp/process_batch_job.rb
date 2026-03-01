# frozen_string_literal: true

class Sftp::ProcessBatchJob < ApplicationJob
  queue_as :default

  def perform(batch_path:)
    Sftp::BatchCampaignService.new(batch_path: batch_path).perform
  end
end
