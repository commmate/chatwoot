class V2::Reports::CampaignListBuilder
  include DateRangeHelper
  pattr_initialize [:account!, :params!]

  def build
    campaigns = campaigns_in_range.includes(:inbox, :delivery_report)
    engagement = fetch_engagement_counts(campaigns)

    campaigns.map { |campaign| build_campaign_row(campaign, engagement) }
  end

  private

  def campaigns_in_range
    @campaigns_in_range ||= account.campaigns.where(created_at: range)
  end

  def fetch_engagement_counts(campaigns)
    report_ids = campaigns.filter_map { |c| c.delivery_report&.id }
    return {} if report_ids.empty?

    scope = CampaignMessageMapping.where(campaign_delivery_report_id: report_ids)
    {
      replies: scope.where.not(replied_at: nil).group(:campaign_delivery_report_id).count,
      opened: scope.where.not(opened_at: nil).group(:campaign_delivery_report_id).count,
      read: scope.where(status: 'read').group(:campaign_delivery_report_id).count,
      clicked: scope.where.not(clicked_at: nil).group(:campaign_delivery_report_id).count
    }
  end

  def build_campaign_row(campaign, engagement)
    report = campaign.delivery_report
    metrics = extract_metrics(report, engagement)

    campaign_identity(campaign).merge(metrics).merge(
      scheduled_at: campaign.scheduled_at,
      completed_at: report&.completed_at
    )
  end

  def campaign_identity(campaign)
    {
      id: campaign.id,
      title: campaign.title,
      inbox_name: campaign.inbox&.name,
      channel_type: campaign.inbox&.channel_type,
      campaign_type: campaign.campaign_type,
      campaign_status: campaign.campaign_status,
      source: campaign.additional_attributes&.dig('sftp_source') ? 'SFTP' : 'Manual'
    }
  end

  def extract_metrics(report, engagement)
    return { total: 0, succeeded: 0, failed: 0, replies: 0, reply_rate: 0, opened: 0, clicked: 0 } unless report

    succeeded = report.succeeded
    rid = report.id
    replies = engagement.dig(:replies, rid) || 0
    opened = (engagement.dig(:opened, rid) || 0) + (engagement.dig(:read, rid) || 0)
    clicked = engagement.dig(:clicked, rid) || 0

    {
      total: report.total, succeeded: succeeded, failed: report.failed,
      replies: replies, reply_rate: pct(replies, succeeded),
      opened: opened, open_rate: pct(opened, succeeded),
      clicked: clicked, click_rate: pct(clicked, succeeded)
    }
  end

  def pct(numerator, denominator)
    return 0 unless denominator.positive?

    (numerator.to_f / denominator * 100).round(2)
  end
end
