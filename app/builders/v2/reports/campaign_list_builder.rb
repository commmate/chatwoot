class V2::Reports::CampaignListBuilder
  include DateRangeHelper
  pattr_initialize [:account!, :params!]

  def build
    campaigns = campaigns_in_range.includes(:inbox, :delivery_report)
    reply_counts = fetch_reply_counts(campaigns)

    campaigns.map { |campaign| build_campaign_row(campaign, reply_counts) }
  end

  private

  def campaigns_in_range
    @campaigns_in_range ||= account.campaigns.where(created_at: range)
  end

  def fetch_reply_counts(campaigns)
    report_ids = campaigns.filter_map { |c| c.delivery_report&.id }
    return {} if report_ids.empty?

    CampaignMessageMapping
      .where(campaign_delivery_report_id: report_ids)
      .where.not(replied_at: nil)
      .group(:campaign_delivery_report_id)
      .count
  end

  def build_campaign_row(campaign, reply_counts)
    report = campaign.delivery_report
    metrics = extract_metrics(report, reply_counts)

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

  def extract_metrics(report, reply_counts)
    return { total: 0, succeeded: 0, failed: 0, replies: 0, reply_rate: 0 } unless report

    succeeded = report.succeeded
    replies = reply_counts[report.id] || 0
    rate = succeeded.positive? ? (replies.to_f / succeeded * 100).round(2) : 0

    { total: report.total, succeeded: succeeded, failed: report.failed, replies: replies, reply_rate: rate }
  end
end
