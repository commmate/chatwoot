class V2::Reports::CampaignBreakdownBuilder
  include DateRangeHelper
  pattr_initialize [:account!, :params!]

  BREAKDOWN_TYPES = %w[by_inbox by_channel_type delivery_status by_hour_and_day].freeze

  def build
    return {} unless BREAKDOWN_TYPES.include?(params[:breakdown_type])

    send(params[:breakdown_type])
  end

  private

  def campaigns_in_range
    @campaigns_in_range ||= account.campaigns.where(created_at: range)
  end

  def delivery_reports
    @delivery_reports ||= CampaignDeliveryReport.where(campaign_id: campaigns_in_range.select(:id))
  end

  def by_inbox
    campaigns_in_range
      .joins(:inbox)
      .group('inboxes.name')
      .count
  end

  def by_channel_type
    raw = campaigns_in_range
          .joins(:inbox)
          .group('inboxes.channel_type')
          .count

    raw.transform_keys { |k| channel_type_label(k) }
  end

  def delivery_status
    {
      succeeded: delivery_reports.sum(:succeeded),
      failed: delivery_reports.sum(:failed),
      pending: delivery_reports.where(status: 'pending').sum(:total)
    }
  end

  def by_hour_and_day
    mappings = CampaignMessageMapping
               .where(campaign_delivery_report_id: delivery_reports.select(:id))

    matrix = Array.new(7) { Array.new(24, 0) }
    mappings.pluck(:created_at).each do |ts|
      matrix[ts.wday][ts.hour] += 1
    end
    matrix
  end

  def channel_type_label(channel_type)
    {
      'Channel::Whatsapp' => 'WhatsApp',
      'Channel::Email' => 'Email',
      'Channel::TwilioSms' => 'Twilio SMS',
      'Channel::Sms' => 'SMS',
      'Channel::WebWidget' => 'Website'
    }.fetch(channel_type, channel_type)
  end
end
