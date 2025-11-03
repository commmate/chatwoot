<script setup>
import { ref, reactive, computed, onMounted } from 'vue';
import { debounce } from 'lodash';
import { useStore } from 'dashboard/composables/store';
import CustomAssetsAPI from '../../../routes/dashboard/api/customAssets';
import CustomAssetItem from './CustomAssetItem.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  contactId: {
    type: [Number, String],
    required: true,
  },
  showSearch: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['share']);

const store = useStore();
const enabledAssets = computed(() =>
  store.getters['customAssets/getEnabledAssets']
);

const assets = reactive({});
const loading = reactive({});
const searchQueries = reactive({});

const fetchAssets = async (assetId, options = {}) => {
  loading[assetId] = true;

  try {
    const response = await CustomAssetsAPI.fetchAssets(
      assetId,
      props.contactId,
      options
    );
    assets[assetId] = response.data.assets;
  } catch (error) {
    console.error('Failed to fetch assets:', error);
    assets[assetId] = [];
  } finally {
    loading[assetId] = false;
  }
};

const debounceSearch = debounce((assetId) => {
  fetchAssets(assetId, { search: searchQueries[assetId] });
}, 300);

const shareAsset = (asset, config) => {
  emit('share', asset, config);
};

onMounted(() => {
  // Load custom assets if not already loaded
  if (enabledAssets.value.length === 0) {
    store.dispatch('customAssets/get');
  }

  // Fetch assets for each enabled asset type
  enabledAssets.value.forEach((asset) => {
    fetchAssets(asset.id);
  });
});
</script>

<template>
  <div>
    <div v-for="assetConfig in enabledAssets" :key="assetConfig.id">
      <div class="px-4 py-3 border-b border-n-slate-3">
        <h3 class="text-sm font-semibold text-n-slate-12">
          {{ assetConfig.name }}
        </h3>
        <p v-if="assetConfig.description" class="text-xs text-n-slate-11 mt-0.5">
          {{ assetConfig.description }}
        </p>
      </div>

      <!-- Search (if enabled) -->
      <div v-if="showSearch" class="px-4 py-2 border-b border-n-slate-3">
        <input
          v-model="searchQueries[assetConfig.id]"
          type="text"
          :placeholder="`Search ${assetConfig.name}...`"
          class="w-full px-3 py-2 border border-n-slate-6 rounded text-sm focus:ring-2 focus:ring-n-brand focus:border-transparent"
          @input="debounceSearch(assetConfig.id)"
        />
      </div>

      <!-- Loading State -->
      <div
        v-if="loading[assetConfig.id]"
        class="flex justify-center items-center p-6"
      >
        <Spinner size="32" class="text-n-brand" />
      </div>

      <!-- Assets List -->
      <div
        v-else-if="assets[assetConfig.id]?.length"
        class="divide-y divide-n-slate-3"
      >
        <CustomAssetItem
          v-for="(asset, index) in assets[assetConfig.id]"
          :key="asset.id || index"
          :asset="asset"
          :config="assetConfig"
          @share="shareAsset"
        />
      </div>

      <!-- Empty State -->
      <div v-else class="px-4 py-6 text-center text-n-slate-11">
        <fluent-icon icon="inbox" size="32" class="mb-2 opacity-50" />
        <p class="text-sm">No {{ assetConfig.name }} found</p>
      </div>
    </div>

    <!-- Empty State: No Assets Configured -->
    <div
      v-if="enabledAssets.length === 0"
      class="px-4 py-6 text-center text-n-slate-11"
    >
      <fluent-icon icon="database" size="32" class="mb-2 opacity-50" />
      <p class="text-sm">No custom assets configured</p>
      <p class="text-xs mt-1">Contact your administrator to set up custom assets</p>
    </div>
  </div>
</template>

