import CustomAssetsAPI from '../../api/customAssets';

const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getCustomAssets(_state) {
    return _state.records;
  },
  getEnabledAssets(_state) {
    return _state.records.filter(asset => asset.enabled);
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getCustomAssetById: _state => id => {
    return _state.records.find(record => record.id === Number(id));
  },
};

export const actions = {
  get: async ({ commit }) => {
    commit('setFetchingStatus', true);
    try {
      const response = await CustomAssetsAPI.get();
      commit('setCustomAssets', response.data);
    } catch (error) {
      // Handle error
      console.error('Error fetching custom assets:', error);
    } finally {
      commit('setFetchingStatus', false);
    }
  },

  create: async ({ commit }, assetData) => {
    commit('setCreatingStatus', true);
    try {
      const response = await CustomAssetsAPI.create(assetData);
      commit('addCustomAsset', response.data);
      return response.data;
    } catch (error) {
      throw error;
    } finally {
      commit('setCreatingStatus', false);
    }
  },

  update: async ({ commit }, { id, ...assetData }) => {
    commit('setUpdatingStatus', true);
    try {
      const response = await CustomAssetsAPI.update(id, assetData);
      commit('updateCustomAsset', response.data);
      return response.data;
    } catch (error) {
      throw error;
    } finally {
      commit('setUpdatingStatus', false);
    }
  },

  delete: async ({ commit }, id) => {
    commit('setDeletingStatus', true);
    try {
      await CustomAssetsAPI.delete(id);
      commit('deleteCustomAsset', id);
    } catch (error) {
      throw error;
    } finally {
      commit('setDeletingStatus', false);
    }
  },
};

export const mutations = {
  setFetchingStatus(_state, status) {
    _state.uiFlags.isFetching = status;
  },
  setCreatingStatus(_state, status) {
    _state.uiFlags.isCreating = status;
  },
  setUpdatingStatus(_state, status) {
    _state.uiFlags.isUpdating = status;
  },
  setDeletingStatus(_state, status) {
    _state.uiFlags.isDeleting = status;
  },
  setCustomAssets(_state, data) {
    _state.records = data;
  },
  addCustomAsset(_state, data) {
    _state.records.push(data);
  },
  updateCustomAsset(_state, data) {
    const index = _state.records.findIndex(
      record => record.id === data.id
    );
    if (index !== -1) {
      _state.records.splice(index, 1, data);
    }
  },
  deleteCustomAsset(_state, id) {
    _state.records = _state.records.filter(record => record.id !== Number(id));
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};


