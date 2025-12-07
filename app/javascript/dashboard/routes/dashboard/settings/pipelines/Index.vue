<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import BaseSettingsHeader from 'dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue';
import SettingsLayout from 'dashboard/routes/dashboard/settings/SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import PipelineTableRow from './PipelineTableRow.vue';
import PipelineEditor from './PipelineEditor.vue';
import PipelinesAPI from '../../../../api/pipelines';

const { t } = useI18n();
const route = useRoute();
const store = useStore();

const pipelines = ref([]);
const isLoading = ref(false);
const showDeletePopup = ref(false);
const showAddPopup = ref(false);
const showEditPopup = ref(false);
const selectedPipeline = ref(null);

const currentUser = computed(() => store.getters.getCurrentUser);

// Permission checks
const canCreatePipelines = computed(() => {
  const { role, custom_role } = currentUser.value;
  if (role === 'administrator') return true;
  if (custom_role?.permissions) {
    return custom_role.permissions.includes('pipeline_create');
  }
  return false;
});

const canManagePipelines = computed(() => {
  const { role, custom_role } = currentUser.value;
  if (role === 'administrator') return true;
  if (custom_role?.permissions) {
    return custom_role.permissions.includes('pipeline_manage');
  }
  return false;
});

const fetchPipelines = async () => {
  isLoading.value = true;
  try {
    const response = await PipelinesAPI.get();
    pipelines.value = response.data || [];
  } finally {
    isLoading.value = false;
  }
};

const openAddPopup = () => {
  selectedPipeline.value = null;
  showAddPopup.value = true;
};

const hideAddPopup = () => {
  showAddPopup.value = false;
  selectedPipeline.value = null;
};

const openEditPopup = pipeline => {
  selectedPipeline.value = pipeline;
  showEditPopup.value = true;
};

const hideEditPopup = () => {
  showEditPopup.value = false;
  selectedPipeline.value = null;
};

const openDeletePopup = pipeline => {
  selectedPipeline.value = pipeline;
  showDeletePopup.value = true;
};

const closeDeletePopup = () => {
  showDeletePopup.value = false;
  selectedPipeline.value = null;
};

const submitPipeline = async () => {
  await fetchPipelines();
  hideAddPopup();
  hideEditPopup();
};

const confirmDeletion = async () => {
  try {
    await PipelinesAPI.delete(selectedPipeline.value.id);
    useAlert(t('PIPELINES.DELETE.SUCCESS'));
    fetchPipelines();
  } catch (error) {
    useAlert(t('PIPELINES.DELETE.ERROR'));
  } finally {
    closeDeletePopup();
  }
};

const tableHeaders = computed(() => [
  t('PIPELINES.LIST.TABLE_HEADER.NAME'),
  t('PIPELINES.LIST.TABLE_HEADER.DESCRIPTION'),
  t('PIPELINES.LIST.TABLE_HEADER.STAGES'),
  t('PIPELINES.LIST.TABLE_HEADER.CONVERSATIONS'),
  t('PIPELINES.LIST.TABLE_HEADER.ACTIONS'),
]);

onMounted(() => {
  fetchPipelines();
});
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="$t('PIPELINES.LOADING')"
    :no-records-found="!pipelines.length"
    :no-records-message="$t('PIPELINES.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('PIPELINES.HEADER')"
        :description="$t('PIPELINES.DESCRIPTION')"
        :link-text="$t('PIPELINES.LEARN_MORE')"
        feature-name="pipelines"
      >
        <template #actions>
          <Button
            v-if="canCreatePipelines"
            icon="i-lucide-circle-plus"
            :label="$t('PIPELINES.HEADER_BTN_TXT')"
            @click="openAddPopup"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <table class="min-w-full divide-y divide-n-weak">
        <thead>
          <th
            v-for="thHeader in tableHeaders"
            :key="thHeader"
            class="py-4 ltr:pr-4 rtl:pl-4 text-left font-semibold text-n-slate-11"
          >
            {{ thHeader }}
          </th>
        </thead>
        <tbody class="divide-y divide-n-weak text-n-slate-11">
          <PipelineTableRow
            v-for="pipeline in pipelines"
            :key="pipeline.id"
            :pipeline="pipeline"
            :can-manage="canManagePipelines"
            :can-create="canCreatePipelines"
            @edit="openEditPopup"
            @delete="openDeletePopup"
          />
        </tbody>
      </table>
    </template>

    <woot-modal
      v-model:show="showAddPopup"
      size="medium"
      :on-close="hideAddPopup"
    >
      <PipelineEditor
        v-if="showAddPopup"
        :on-close="hideAddPopup"
        @save="submitPipeline"
      />
    </woot-modal>

    <woot-modal
      v-model:show="showEditPopup"
      size="medium"
      :on-close="hideEditPopup"
    >
      <PipelineEditor
        v-if="showEditPopup"
        :pipeline="selectedPipeline"
        :on-close="hideEditPopup"
        @save="submitPipeline"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeletePopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="$t('PIPELINES.DELETE.CONFIRM.TITLE')"
      :message="$t('PIPELINES.DELETE.CONFIRM.MESSAGE')"
      :message-value="selectedPipeline?.name"
      :confirm-text="$t('PIPELINES.DELETE.CONFIRM.YES')"
      :reject-text="$t('PIPELINES.DELETE.CONFIRM.NO')"
    />
  </SettingsLayout>
</template>
