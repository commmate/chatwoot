class Campaigns::TriggerOneoffCampaignJob < ApplicationJob
  queue_as :resend_campaigns

  def perform(campaign)
    campaign.trigger!
  end
end
