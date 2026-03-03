/* global axios */
import ApiClient from './ApiClient';

class ResendAPI extends ApiClient {
  constructor() {
    super('resend', { accountScoped: true });
  }

  provisionDomain(data) {
    return axios.post(`${this.url}/provision_domain`, data);
  }

  listDomains() {
    return axios.get(`${this.url}/domains`);
  }

  checkDomainStatus(inboxId) {
    return axios.get(`${this.url}/domain_status/${inboxId}`);
  }

  verifyDomain(inboxId) {
    return axios.post(`${this.url}/verify_domain/${inboxId}`);
  }

  sendDnsInstructions(data) {
    return axios.post(`${this.url}/send_dns_instructions`, data);
  }

  configureWebhook(inboxId) {
    return axios.post(`${this.url}/configure_webhook/${inboxId}`);
  }
}

export default new ResendAPI();
