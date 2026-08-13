/* global axios */
import ApiClient from './ApiClient';

const getTimeOffset = () => -new Date().getTimezoneOffset() / 60;

class ReportsAPI extends ApiClient {
  constructor() {
    super('reports', { accountScoped: true, apiVersion: 'v2' });
  }

  getReports({
    metric,
    from,
    to,
    type = 'account',
    id,
    groupBy,
    businessHours,
  }) {
    return axios.get(`${this.url}`, {
      params: {
        metric,
        since: from,
        until: to,
        type,
        id,
        group_by: groupBy,
        business_hours: businessHours,
        timezone_offset: getTimeOffset(),
      },
    });
  }

  getDrilldown({
    metric,
    bucketTimestamp,
    from,
    to,
    type = 'account',
    id,
    groupBy,
    businessHours,
    page,
    perPage,
    signal,
  }) {
    const requestConfig = {
      params: {
        metric,
        bucket_timestamp: bucketTimestamp,
        since: from,
        until: to,
        type,
        id,
        group_by: groupBy,
        business_hours: businessHours,
        timezone_offset: getTimeOffset(),
        page,
        per_page: perPage,
      },
    };

    if (signal) {
      requestConfig.signal = signal;
    }

    return axios.get(`${this.url}/drilldown`, requestConfig);
  }

  // eslint-disable-next-line default-param-last
  getSummary(since, until, type = 'account', id, groupBy, businessHours) {
    return axios.get(`${this.url}/summary`, {
      params: {
        since,
        until,
        type,
        id,
        group_by: groupBy,
        business_hours: businessHours,
        timezone_offset: getTimeOffset(),
      },
    });
  }

  getConversationMetric(type = 'account', page = 1) {
    return axios.get(`${this.url}/conversations`, {
      params: {
        type,
        page,
      },
    });
  }

  getAgentReports({ from: since, to: until, businessHours }) {
    return axios.get(`${this.url}/agents`, {
      params: { since, until, business_hours: businessHours },
    });
  }

  getConversationsSummaryReports({ from: since, to: until, businessHours }) {
    return axios.get(`${this.url}/conversations_summary`, {
      params: { since, until, business_hours: businessHours },
    });
  }

  getConversationTrafficCSV({ daysBefore = 6 } = {}) {
    return axios.get(`${this.url}/conversation_traffic`, {
      params: { timezone_offset: getTimeOffset(), days_before: daysBefore },
    });
  }

  getLabelReports({ from: since, to: until, businessHours }) {
    return axios.get(`${this.url}/labels`, {
      params: { since, until, business_hours: businessHours },
    });
  }

  getInboxReports({ from: since, to: until, businessHours }) {
    return axios.get(`${this.url}/inboxes`, {
      params: { since, until, business_hours: businessHours },
    });
  }

  getTeamReports({ from: since, to: until, businessHours }) {
    return axios.get(`${this.url}/teams`, {
      params: { since, until, business_hours: businessHours },
    });
  }

  getBotMetrics({ from, to } = {}) {
    return axios.get(`${this.url}/bot_metrics`, {
      params: { since: from, until: to },
    });
  }

  getBotSummary({ from, to, groupBy, businessHours } = {}) {
    return axios.get(`${this.url}/bot_summary`, {
      params: {
        since: from,
        until: to,
        type: 'account',
        group_by: groupBy,
        business_hours: businessHours,
      },
    });
  }

  getCampaignSummary({ from, to }) {
    const summaryUrl = this.url.replace('/reports', '/summary_reports');
    return axios.get(`${summaryUrl}/campaign`, {
      params: { since: from, until: to },
    });
  }

  getCampaignList({ from, to }) {
    return axios.get(`${this.url}/campaign_list`, {
      params: { since: from, until: to },
    });
  }

  getCampaignTimeseries({ from, to, groupBy }) {
    return axios.get(`${this.url}/campaign_timeseries`, {
      params: { since: from, until: to, group_by: groupBy },
    });
  }

  getCampaignBreakdown({ from, to, breakdownType }) {
    return axios.get(`${this.url}/campaign_breakdown`, {
      params: { since: from, until: to, breakdown_type: breakdownType },
    });
  }

  getCampaignsCSV({ from, to }) {
    return axios.get(`${this.url}/campaigns`, {
      params: { since: from, until: to },
    });
  }

  getCampaignDeliveryCSV({ from, to }) {
    return axios.get(`${this.url}/campaign_delivery_detail`, {
      params: { since: from, until: to },
    });
  }

  getCampaignMessages({
    campaignId,
    page = 1,
    perPage = 25,
    sortBy,
    sortOrder,
    filter,
  }) {
    return axios.get(`${this.url}/campaign_messages`, {
      params: {
        campaign_id: campaignId,
        page,
        per_page: perPage,
        sort_by: sortBy,
        sort_order: sortOrder,
        filter,
      },
    });
  }
}

export default new ReportsAPI();
