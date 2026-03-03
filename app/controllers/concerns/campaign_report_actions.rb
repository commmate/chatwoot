module CampaignReportActions
  extend ActiveSupport::Concern

  def campaign_list
    builder = V2::Reports::CampaignListBuilder.new(account: Current.account, params: campaign_report_params)
    render json: builder.build
  end

  def campaigns
    @report_data = generate_campaigns_report
    generate_csv('campaigns_report', 'api/v2/accounts/reports/campaigns')
  end

  def campaign_delivery_detail
    @report_data = generate_campaign_delivery_report
    generate_csv('campaign_delivery_detail', 'api/v2/accounts/reports/campaign_delivery_detail')
  end

  def campaign_timeseries
    builder = V2::Reports::CampaignListBuilder.new(account: Current.account, params: campaign_report_params)
    data = builder.build
    render json: group_campaigns_by_period(data, params[:group_by] || 'day')
  end

  def campaign_breakdown
    builder = V2::Reports::CampaignBreakdownBuilder.new(
      account: Current.account,
      params: campaign_breakdown_params
    )
    render json: builder.build
  end

  def campaign_messages
    builder = V2::Reports::CampaignMessagesBuilder.new(
      account: Current.account,
      params: campaign_messages_params
    )
    render json: builder.build
  end

  private

  def campaign_report_params
    { since: params[:since], until: params[:until] }
  end

  def campaign_breakdown_params
    { since: params[:since], until: params[:until], breakdown_type: params[:breakdown_type] }
  end

  def campaign_messages_params
    {
      campaign_id: params[:campaign_id], page: params[:page], per_page: params[:per_page],
      sort_by: params[:sort_by], sort_order: params[:sort_order], filter: params[:filter]
    }
  end
end
