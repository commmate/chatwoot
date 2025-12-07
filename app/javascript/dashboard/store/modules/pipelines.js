import axios from 'axios';

const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

const getters = {
  getPipelines: $state => $state.records,
  getPipelineById: $state => id => $state.records.find(pipeline => pipeline.id === id),
  getUIFlags: $state => $state.uiFlags,
};

const actions = {
  async get({ commit }, accountId) {
    commit('SET_UI_FLAG', { isFetching: true });
    try {
      const response = await axios.get(`/api/v1/accounts/${accountId}/pipelines`);
      commit('SET_PIPELINES', response.data);
    } catch (error) {
      console.error('Error fetching pipelines:', error);
    } finally {
      commit('SET_UI_FLAG', { isFetching: false });
    }
  },

  async create({ commit }, { accountId, pipeline }) {
    commit('SET_UI_FLAG', { isCreating: true });
    try {
      const response = await axios.post(
        `/api/v1/accounts/${accountId}/pipelines`,
        { pipeline }
      );
      commit('ADD_PIPELINE', response.data);
      return response.data;
    } catch (error) {
      throw error;
    } finally {
      commit('SET_UI_FLAG', { isCreating: false });
    }
  },

  async update({ commit }, { accountId, pipelineId, pipeline }) {
    commit('SET_UI_FLAG', { isUpdating: true });
    try {
      const response = await axios.put(
        `/api/v1/accounts/${accountId}/pipelines/${pipelineId}`,
        { pipeline }
      );
      commit('UPDATE_PIPELINE', response.data);
      return response.data;
    } catch (error) {
      throw error;
    } finally {
      commit('SET_UI_FLAG', { isUpdating: false });
    }
  },

  async delete({ commit }, { accountId, pipelineId }) {
    commit('SET_UI_FLAG', { isDeleting: true });
    try {
      await axios.delete(`/api/v1/accounts/${accountId}/pipelines/${pipelineId}`);
      commit('DELETE_PIPELINE', pipelineId);
    } catch (error) {
      throw error;
    } finally {
      commit('SET_UI_FLAG', { isDeleting: false });
    }
  },

  async reorderStages({ commit }, { accountId, pipelineId, stages }) {
    try {
      const response = await axios.post(
        `/api/v1/accounts/${accountId}/pipelines/${pipelineId}/reorder_stages`,
        { stages }
      );
      commit('UPDATE_PIPELINE', response.data);
      return response.data;
    } catch (error) {
      throw error;
    }
  },
};

const mutations = {
  SET_PIPELINES($state, pipelines) {
    $state.records = pipelines;
  },

  ADD_PIPELINE($state, pipeline) {
    $state.records.push(pipeline);
  },

  UPDATE_PIPELINE($state, updatedPipeline) {
    const index = $state.records.findIndex(p => p.id === updatedPipeline.id);
    if (index !== -1) {
      $state.records.splice(index, 1, updatedPipeline);
    }
  },

  DELETE_PIPELINE($state, pipelineId) {
    $state.records = $state.records.filter(p => p.id !== pipelineId);
  },

  SET_UI_FLAG($state, flag) {
    $state.uiFlags = { ...$state.uiFlags, ...flag };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};

