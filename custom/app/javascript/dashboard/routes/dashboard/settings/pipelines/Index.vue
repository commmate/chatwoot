<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import BaseSettingsHeader from '../../../../../../app/javascript/dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue';
import SettingsLayout from '../../../../../../app/javascript/dashboard/routes/dashboard/settings/SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import PipelineTableRow from './PipelineTableRow.vue';
import axios from 'axios';

const { t } = useI18n();
const route = useRoute();

const pipelines = ref([]);
const isLoading = ref(false);
const showDeletePopup = ref(false);
const selectedPipeline = ref(null);

const accountId = computed(() => route.params.accountId);

const fetchPipelines = async () => {
  isLoading.value = true;
  try {
    const response = await axios.get(`/api/v1/accounts/${accountId.value}/pipelines`);
    pipelines.value = response.data;
  } catch (error) {
    useAlert(t('PIPELINES.LIST.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const openDeletePopup = (pipeline) => {
  selectedPipeline.value = pipeline;
  showDeletePopup.value = true;
};

const closeDeletePopup = () => {
  showDeletePopup.value = false;
  selectedPipeline.value = null;
};

const confirmDeletion = async () => {
  try {
    await axios.delete(`/api/v1/accounts/${accountId.value}/pipelines/${selectedPipeline.value.id}`);
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
          <router-link :to="{ name: 'pipelines_new' }">
            <Button
              icon="i-lucide-circle-plus"
              :label="$t('PIPELINES.HEADER_BTN_TXT')"
            />
          </router-link>
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
            @delete="openDeletePopup"
          />
        </tbody>
      </table>

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
    </template>
  </SettingsLayout>
</template>

