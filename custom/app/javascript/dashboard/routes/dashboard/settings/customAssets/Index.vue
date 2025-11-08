<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import AssetConfigurationModal from './AssetConfigurationModal.vue';

const store = useStore();
const showModal = ref(false);
const selectedAsset = ref(null);
const loading = ref(false);

const customAssets = useMapGetter('customAssets/getCustomAssets');
const currentUser = useMapGetter('getCurrentUser');

const isAdmin = computed(() => currentUser.value.type === 'SuperAdmin');

const n8nUrl = computed(() => {
  return import.meta.env.VITE_N8N_URL || 'http://localhost:5678';
});

const openModal = (asset = null) => {
  selectedAsset.value = asset;
  showModal.value = true;
};

const closeModal = () => {
  selectedAsset.value = null;
  showModal.value = false;
};

const handleSaved = () => {
  closeModal();
  loadAssets();
  useAlert(selectedAsset.value ? 'Asset updated successfully!' : 'Asset created successfully!');
};

const handleDelete = async asset => {
  if (!confirm(`Are you sure you want to delete "${asset.name}"?`)) return;

  try {
    await store.dispatch('customAssets/delete', asset.id);
    useAlert('Asset deleted successfully!');
  } catch (error) {
    useAlert('Failed to delete asset');
  }
};

const toggleEnabled = async asset => {
  try {
    await store.dispatch('customAssets/update', {
      id: asset.id,
      enabled: !asset.enabled,
    });
    useAlert(`Asset ${asset.enabled ? 'disabled' : 'enabled'} successfully!`);
  } catch (error) {
    useAlert('Failed to update asset');
  }
};

const loadAssets = async () => {
  loading.value = true;
  try {
    await store.dispatch('customAssets/get');
  } catch (error) {
    console.error('Failed to load custom assets:', error);
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  loadAssets();
});
</script>

<template>
  <div class="flex-1 overflow-auto p-8">
    <div class="flex items-center justify-between mb-6">
      <div>
        <h1 class="text-2xl font-semibold text-n-slate-12">
          Custom Assets
        </h1>
        <p class="text-sm text-n-slate-11 mt-1">
          Configure external API integrations using n8n workflows
        </p>
      </div>
      <button
        v-if="isAdmin"
        class="btn-primary"
        @click="openModal()"
      >
        <fluent-icon icon="add" class="mr-2" size="16" />
        Add Custom Asset
      </button>
    </div>

    <!-- Info Banner -->
    <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
      <div class="flex items-start">
        <fluent-icon icon="info" class="text-blue-600 mr-3 mt-0.5" size="20" />
        <div class="flex-1">
          <h3 class="font-semibold text-blue-900 mb-1">
            Powered by n8n
          </h3>
          <p class="text-sm text-blue-800 mb-2">
            Build visual workflows in n8n to fetch data from any API. No coding required!
          </p>
          <a
            :href="n8nUrl"
            target="_blank"
            class="inline-flex items-center text-sm text-blue-600 hover:text-blue-800 underline"
          >
            Open n8n Workflow Editor
            <fluent-icon icon="open" class="ml-1" size="14" />
          </a>
        </div>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="flex justify-center items-center py-12">
      <spinner size="48" class="text-n-brand" />
    </div>

    <!-- Empty State -->
    <div v-else-if="!customAssets.length" class="text-center py-12">
      <fluent-icon icon="database" size="64" class="text-n-slate-8 mb-4" />
      <h3 class="text-lg font-semibold text-n-slate-12 mb-2">
        No custom assets configured
      </h3>
      <p class="text-n-slate-11 mb-6">
        Create your first custom asset to fetch external data from any API
      </p>
      <button
        v-if="isAdmin"
        class="btn-primary"
        @click="openModal()"
      >
        <fluent-icon icon="add" class="mr-2" size="16" />
        Add Custom Asset
      </button>
    </div>

    <!-- Assets Table -->
    <div v-else class="bg-white rounded-lg border border-n-slate-6 overflow-hidden">
      <table class="w-full">
        <thead class="bg-n-slate-2 border-b border-n-slate-6">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-n-slate-11 uppercase tracking-wider">
              Name
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-n-slate-11 uppercase tracking-wider">
              Type
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-n-slate-11 uppercase tracking-wider">
              n8n Workflow
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-n-slate-11 uppercase tracking-wider">
              Status
            </th>
            <th class="px-6 py-3 text-right text-xs font-medium text-n-slate-11 uppercase tracking-wider">
              Actions
            </th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-n-slate-6">
          <tr
            v-for="asset in customAssets"
            :key="asset.id"
            class="hover:bg-n-slate-1 transition-colors"
          >
            <td class="px-6 py-4 whitespace-nowrap">
              <div class="flex items-center">
                <div>
                  <div class="text-sm font-medium text-n-slate-12">
                    {{ asset.name }}
                  </div>
                  <div v-if="asset.description" class="text-xs text-n-slate-11">
                    {{ asset.description }}
                  </div>
                </div>
              </div>
            </td>
            <td class="px-6 py-4 whitespace-nowrap">
              <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-n-slate-3 text-n-slate-11">
                {{ asset.asset_type }}
              </span>
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm">
              <a
                v-if="asset.n8n_workflow_id"
                :href="`${n8nUrl}/workflow/${asset.n8n_workflow_id}`"
                target="_blank"
                class="text-blue-600 hover:text-blue-800 inline-flex items-center"
              >
                View Workflow
                <fluent-icon icon="open" class="ml-1" size="12" />
              </a>
              <span v-else class="text-n-slate-11">—</span>
            </td>
            <td class="px-6 py-4 whitespace-nowrap">
              <button
                v-if="isAdmin"
                @click="toggleEnabled(asset)"
                class="inline-flex items-center"
              >
                <span
                  :class="[
                    'px-2 py-1 inline-flex text-xs leading-5 font-semibold rounded-full',
                    asset.enabled ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
                  ]"
                >
                  {{ asset.enabled ? 'Enabled' : 'Disabled' }}
                </span>
              </button>
              <span
                v-else
                :class="[
                  'px-2 py-1 inline-flex text-xs leading-5 font-semibold rounded-full',
                  asset.enabled ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
                ]"
              >
                {{ asset.enabled ? 'Enabled' : 'Disabled' }}
              </span>
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
              <div class="flex justify-end gap-2">
                <button
                  v-if="isAdmin"
                  @click="openModal(asset)"
                  class="text-blue-600 hover:text-blue-900"
                  title="Edit"
                >
                  <fluent-icon icon="edit" size="16" />
                </button>
                <button
                  v-if="isAdmin"
                  @click="handleDelete(asset)"
                  class="text-red-600 hover:text-red-900"
                  title="Delete"
                >
                  <fluent-icon icon="delete" size="16" />
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Modal -->
    <AssetConfigurationModal
      v-if="showModal"
      :asset="selectedAsset"
      @close="closeModal"
      @saved="handleSaved"
    />
  </div>
</template>


