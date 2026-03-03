class V2::Reports::CampaignSummaryBuilder
  include DateRangeHelper
  pattr_initialize [:account!, :params!]

  def build
    {
      campaigns_created: campaigns_in_range.count,
      campaigns_completed: campaigns_in_range.where(campaign_status: :completed).count,
      total_sent: total_succeeded,
      total_failed: delivery_reports.sum(:failed),
      total_replies: replied_mappings_count,
      reply_rate: rate(replied_mappings_count, total_succeeded),
      total_opened: opened_mappings_count,
      open_rate: rate(opened_mappings_count, total_succeeded),
      total_clicked: clicked_mappings_count,
      click_rate: rate(clicked_mappings_count, total_succeeded)
    }
  end

  private

  def campaigns_in_range
    @campaigns_in_range ||= account.campaigns.where(created_at: range)
  end

  def delivery_reports
    @delivery_reports ||= CampaignDeliveryReport.where(campaign_id: campaigns_in_range.select(:id))
  end

  def mappings_scope
    @mappings_scope ||= CampaignMessageMapping.where(campaign_delivery_report_id: delivery_reports.select(:id))
  end

  def total_succeeded
    @total_succeeded ||= delivery_reports.sum(:succeeded)
  end

  def replied_mappings_count
    @replied_mappings_count ||= mappings_scope.where.not(replied_at: nil).count
  end

  def opened_mappings_count
    @opened_mappings_count ||= mappings_scope.where.not(opened_at: nil).count + mappings_scope.where(status: 'read').count
  end

  def clicked_mappings_count
    @clicked_mappings_count ||= mappings_scope.where.not(clicked_at: nil).count
  end

  def rate(numerator, denominator)
    return 0 if denominator.zero?

    (numerator.to_f / denominator * 100).round(2)
  end
end
