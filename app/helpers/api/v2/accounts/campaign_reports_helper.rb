module Api::V2::Accounts::CampaignReportsHelper
  def generate_campaigns_report
    reports = V2::Reports::CampaignListBuilder.new(
      account: Current.account,
      params: build_params({})
    ).build

    reports.map do |r|
      [r[:title], r[:inbox_name], r[:channel_type], r[:campaign_type], r[:campaign_status],
       r[:source], r[:total], r[:succeeded], r[:failed], r[:replies],
       "#{r[:reply_rate]}%", r[:scheduled_at], r[:completed_at]]
    end
  end

  def generate_campaign_delivery_report
    campaign_ids = Current.account.campaigns.where(created_at: campaign_date_range).pluck(:id)
    report_ids = CampaignDeliveryReport.where(campaign_id: campaign_ids).pluck(:id)
    mappings = CampaignMessageMapping.where(campaign_delivery_report_id: report_ids)
                                     .includes(:contact, campaign_delivery_report: :campaign)

    mappings.map do |m|
      contact = m.contact
      campaign_title = m.campaign_delivery_report&.campaign&.title
      contact_identifier = contact.email.presence || contact.phone_number.presence || contact.name
      [campaign_title, contact_identifier, m.status, m.replied_at, m.error_code, m.error_message]
    end
  end

  def group_campaigns_by_period(data, group_by = 'day')
    grouped = group_by_period(data, group_by)

    {
      campaigns_created: grouped.transform_values(&:count),
      messages_sent: sum_field(grouped, :succeeded),
      messages_failed: sum_field(grouped, :failed)
    }
  end

  def group_by_period(data, group_by)
    data.group_by { |c| campaign_period_key(c[:scheduled_at] || c[:completed_at], group_by) }.compact
  end

  def sum_field(grouped, field)
    grouped.transform_values { |camps| camps.sum { |c| c[field] } }
  end

  def campaign_period_key(timestamp, group_by)
    return nil if timestamp.blank?

    ts = timestamp.is_a?(String) ? Time.zone.parse(timestamp) : timestamp
    return ts.beginning_of_week.strftime('%Y-%m-%d') if group_by == 'week'
    return ts.beginning_of_month.strftime('%Y-%m') if group_by == 'month'

    ts.strftime('%Y-%m-%d')
  end

  private

  def campaign_date_range
    return unless params[:since].present? && params[:until].present?

    DateTime.strptime(params[:since], '%s')...DateTime.strptime(params[:until], '%s')
  end
end
