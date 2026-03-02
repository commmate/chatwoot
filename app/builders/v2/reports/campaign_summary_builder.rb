class V2::Reports::CampaignSummaryBuilder
  include DateRangeHelper
  pattr_initialize [:account!, :params!]

  def build
    {
      campaigns_created: campaigns_in_range.count,
      campaigns_completed: campaigns_in_range.where(campaign_status: :completed).count,
      total_sent: delivery_reports.sum(:succeeded),
      total_failed: delivery_reports.sum(:failed),
      total_replies: replied_mappings_count,
      reply_rate: calculate_reply_rate
    }
  end

  private

  def campaigns_in_range
    @campaigns_in_range ||= account.campaigns.where(created_at: range)
  end

  def delivery_reports
    @delivery_reports ||= CampaignDeliveryReport.where(campaign_id: campaigns_in_range.select(:id))
  end

  def replied_mappings_count
    @replied_mappings_count ||= CampaignMessageMapping
                                .where(campaign_delivery_report_id: delivery_reports.select(:id))
                                .where.not(replied_at: nil)
                                .count
  end

  def calculate_reply_rate
    total = delivery_reports.sum(:succeeded)
    return 0 if total.zero?

    (replied_mappings_count.to_f / total * 100).round(2)
  end
end
