<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import CustomAssetsAPI from '../../../api/customAssets';

const props = defineProps({
  asset: { type: Object, default: null },
});

const emit = defineEmits(['close', 'saved']);

const store = useStore();
const isEdit = computed(() => !!props.asset);
const n8nUrl = computed(() => import.meta.env.VITE_N8N_URL || 'http://localhost:5678');

const form = ref({
  name: props.asset?.name || '',
  asset_type: props.asset?.asset_type || '',
  description: props.asset?.description || '',
  n8n_webhook_url: props.asset?.n8n_webhook_url || '',
  n8n_workflow_id: props.asset?.n8n_workflow_id || '',
  enabled: props.asset?.enabled !== undefined ? props.asset.enabled : true,
  display_config: props.asset?.display_config || { fields: [] },
});

const testing = ref(false);
const saving = ref(false);
const testResult = ref(null);

const testConnection = async () => {
  if (!form.value.n8n_webhook_url) {
    useAlert('Please enter a webhook URL first');
    return;
  }

  testing.value = true;
  testResult.value = null;

  try {
    const response = await CustomAssetsAPI.testConnection({
      n8n_webhook_url: form.value.n8n_webhook_url,
    });

    testResult.value = {
      success: response.data.success,
      message: response.data.success
        ? '✅ Connection successful!'
        : `❌ ${response.data.error || 'Connection failed'}`,
    };
  } catch (error) {
    testResult.value = {
      success: false,
      message: `❌ Error: ${error.response?.data?.error || error.message}`,
    };
  } finally {
    testing.value = false;
  }
};

const addField = () => {
  if (!form.value.display_config.fields) {
    form.value.display_config.fields = [];
  }
  form.value.display_config.fields.push({
    key: '',
    label: '',
    type: 'text',
    format: '',
  });
};

const removeField = index => {
  form.value.display_config.fields.splice(index, 1);
};

const save = async () => {
  // Validation
  if (!form.value.name || !form.value.asset_type || !form.value.n8n_webhook_url) {
    useAlert('Please fill in all required fields');
    return;
  }

  saving.value = true;

  try {
    if (isEdit.value) {
      await store.dispatch('customAssets/update', {
        id: props.asset.id,
        ...form.value,
      });
    } else {
      await store.dispatch('customAssets/create', form.value);
    }

    emit('saved');
  } catch (error) {
    useAlert(`Failed to ${isEdit.value ? 'update' : 'create'} asset: ${error.message}`);
  } finally {
    saving.value = false;
  }
};
</script>

<template>
  <woot-modal :show.sync="true" :on-close="() => emit('close')">
    <div class="flex flex-col h-auto overflow-hidden">
      <woot-modal-header
        :header-title="isEdit ? 'Edit Custom Asset' : 'Add Custom Asset'"
        :header-content="'Configure n8n workflow integration'"
      />

      <form class="flex flex-col overflow-auto p-6" @submit.prevent="save">
        <!-- Basic Info -->
        <div class="space-y-4 mb-6">
          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-1">
              Asset Name <span class="text-red-600">*</span>
            </label>
            <input
              v-model="form.name"
              type="text"
              placeholder="e.g., Products, Invoices, Orders"
              required
              class="w-full px-3 py-2 border border-n-slate-6 rounded focus:ring-2 focus:ring-n-brand focus:border-transparent"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-1">
              Asset Type <span class="text-red-600">*</span>
            </label>
            <input
              v-model="form.asset_type"
              type="text"
              placeholder="e.g., products, invoices (lowercase, no spaces)"
              required
              class="w-full px-3 py-2 border border-n-slate-6 rounded focus:ring-2 focus:ring-n-brand focus:border-transparent"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-1">
              Description
            </label>
            <textarea
              v-model="form.description"
              placeholder="What data does this asset provide?"
              rows="2"
              class="w-full px-3 py-2 border border-n-slate-6 rounded focus:ring-2 focus:ring-n-brand focus:border-transparent"
            />
          </div>
        </div>

        <!-- n8n Integration Guide -->
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
          <h3 class="font-semibold text-blue-900 mb-2 flex items-center">
            <fluent-icon icon="info" class="mr-2" size="20" />
            n8n Workflow Setup
          </h3>
          <ol class="list-decimal ml-4 text-sm space-y-1 mb-3 text-blue-800">
            <li>Open n8n and create a new workflow</li>
            <li>Add a "Webhook" trigger node (POST method)</li>
            <li>Build your API integration (HTTP requests, auth, etc.)</li>
            <li>Add data transformation/filtering as needed</li>
            <li>Return JSON: array or {items: [...]} or {data: [...]}</li>
            <li>Activate the workflow and copy webhook URL below</li>
          </ol>
          <a
            :href="n8nUrl"
            target="_blank"
            class="inline-flex items-center text-sm text-blue-600 hover:text-blue-800 underline"
          >
            Open n8n Workflow Editor →
          </a>
        </div>

        <!-- Payload Structure Info -->
        <details class="bg-n-slate-2 border border-n-slate-6 rounded-lg p-3 mb-6">
          <summary class="cursor-pointer font-medium text-sm text-n-slate-12">
            Webhook Payload Structure (what n8n receives)
          </summary>
          <pre class="mt-2 text-xs overflow-x-auto p-2 bg-n-slate-1 rounded">{{
            JSON.stringify(
              {
                contact_id: 123,
                email: 'customer@example.com',
                phone: '+1234567890',
                name: 'John Doe',
                custom_attributes: {},
                search_query: '...',
                filters: {},
              },
              null,
              2
            )
          }}</pre>
        </details>

        <!-- n8n Configuration -->
        <div class="space-y-4 mb-6">
          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-1">
              n8n Webhook URL <span class="text-red-600">*</span>
            </label>
            <input
              v-model="form.n8n_webhook_url"
              type="url"
              placeholder="https://your-n8n.com/webhook/..."
              required
              class="w-full px-3 py-2 border border-n-slate-6 rounded font-mono text-sm focus:ring-2 focus:ring-n-brand focus:border-transparent"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-1">
              n8n Workflow ID (optional)
            </label>
            <input
              v-model="form.n8n_workflow_id"
              type="text"
              placeholder="abc123 (for easy access to workflow)"
              class="w-full px-3 py-2 border border-n-slate-6 rounded focus:ring-2 focus:ring-n-brand focus:border-transparent"
            />
          </div>

          <!-- Test Connection -->
          <div>
            <button
              type="button"
              :disabled="!form.n8n_webhook_url || testing"
              class="btn-secondary"
              @click="testConnection"
            >
              <fluent-icon icon="plug-connected" class="mr-2" size="16" />
              {{ testing ? 'Testing...' : 'Test Connection' }}
            </button>
            <span
              v-if="testResult"
              :class="[
                'ml-3 text-sm',
                testResult.success ? 'text-green-600' : 'text-red-600',
              ]"
            >
              {{ testResult.message }}
            </span>
          </div>
        </div>

        <!-- Display Fields Configuration -->
        <div class="border-t border-n-slate-6 pt-6">
          <h3 class="font-semibold text-n-slate-12 mb-2">Display Fields</h3>
          <p class="text-sm text-n-slate-11 mb-4">
            Configure which fields from n8n response to display in Chatwoot
          </p>

          <div class="space-y-3">
            <div
              v-for="(field, index) in form.display_config.fields"
              :key="index"
              class="flex gap-2 items-start"
            >
              <input
                v-model="field.key"
                type="text"
                placeholder="Field key (e.g., name, price)"
                class="flex-1 px-3 py-2 border border-n-slate-6 rounded text-sm"
              />
              <input
                v-model="field.label"
                type="text"
                placeholder="Label (e.g., Product Name)"
                class="flex-1 px-3 py-2 border border-n-slate-6 rounded text-sm"
              />
              <select
                v-model="field.type"
                class="px-3 py-2 border border-n-slate-6 rounded text-sm"
              >
                <option value="text">Text</option>
                <option value="number">Number</option>
                <option value="currency">Currency</option>
                <option value="date">Date</option>
                <option value="link">Link</option>
              </select>
              <button
                type="button"
                class="px-3 py-2 text-red-600 hover:bg-red-50 rounded"
                @click="removeField(index)"
              >
                <fluent-icon icon="delete" size="16" />
              </button>
            </div>
          </div>

          <button
            type="button"
            class="mt-3 text-sm text-blue-600 hover:text-blue-800 inline-flex items-center"
            @click="addField"
          >
            <fluent-icon icon="add" class="mr-1" size="16" />
            Add Field
          </button>
        </div>

        <!-- Submit Buttons -->
        <div class="flex gap-3 pt-6 border-t border-n-slate-6 mt-6">
          <button type="submit" class="btn-primary" :disabled="saving">
            {{ saving ? 'Saving...' : isEdit ? 'Update' : 'Create' }}
          </button>
          <button
            type="button"
            class="btn-secondary"
            @click="emit('close')"
          >
            Cancel
          </button>
        </div>
      </form>
    </div>
  </woot-modal>
</template>


