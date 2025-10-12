/* global axios */
import ApiClient from 'dashboard/api/ApiClient';

class PipelinesAPI extends ApiClient {
  constructor() {
    super('pipelines', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  show(id) {
    return axios.get(`${this.url}/${id}`);
  }

  create(pipelineData) {
    return axios.post(this.url, { pipeline: pipelineData });
  }

  update(id, pipelineData) {
    return axios.patch(`${this.url}/${id}`, { pipeline: pipelineData });
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }

  reorderStages(id, stages) {
    return axios.post(`${this.url}/${id}/reorder_stages`, { stages });
  }
}

export default new PipelinesAPI();

