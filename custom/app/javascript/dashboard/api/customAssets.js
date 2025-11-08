/* global axios */
import ApiClient from 'dashboard/api/ApiClient';

class CustomAssetsAPI extends ApiClient {
  constructor() {
    super('custom_assets', { accountScoped: true });
  }

  fetchAssets(assetId, contactId, options = {}) {
    return axios.get(`${this.url}/${assetId}/fetch_assets`, {
      params: {
        contact_id: contactId,
        search: options.search,
        filters: options.filters,
      },
    });
  }

  testConnection(config) {
    return axios.post(`${this.url}/test_connection`, config);
  }
}

export default new CustomAssetsAPI();


