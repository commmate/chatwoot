<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import axios from 'axios';
import Button from 'dashboard/components-next/button/Button.vue';
import StageManager from './StageManager.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const pipelineName = ref('');
const pipelineDescription = ref('');
const stages = ref([]);
const isLoading = ref(false);
const isSaving = ref(false);

const accountId = computed(() => route.params.accountId);
const pipelineId = computed(() => route.params.pipelineId);
const isEditMode = computed(() => !!pipelineId.value);

const pageTitle = computed(() => 
  isEditMode.value ? t('PIPELINES.EDIT.TITLE') : t('PIPELINES.ADD.TITLE')
);

const fetchPipeline = async () => {
  if (!isEditMode.value) return;

  isLoading.value = true;
  try {
    const response = await axios.get(
      `/api/v1/accounts/${accountId.value}/pipelines/${pipelineId.value}`
    );
    pipelineName.value = response.data.name;
    pipelineDescription.value = response.data.description || '';
    stages.value = response.data.stages || [];
  } catch (error) {
    useAlert(t('PIPELINES.EDIT.LOAD_ERROR'));
    router.push({ name: 'pipelines_list' });
  } finally {
    isLoading.value = false;
  }
};

const savePipeline = async () => {
  if (!pipelineName.value.trim()) {
    useAlert(t('PIPELINES.FORM.NAME_REQUIRED'));
    return;
  }

  if (!stages.value.length) {
    useAlert(t('PIPELINES.FORM.STAGES_REQUIRED'));
    return;
  }

  isSaving.value = true;
  try {
    const pipelineData = {
      name: pipelineName.value.trim(),
      description: pipelineDescription.value.trim(),
      stages: stages.value,
    };

    if (isEditMode.value) {
      await axios.put(
        `/api/v1/accounts/${accountId.value}/pipelines/${pipelineId.value}`,
        { pipeline: pipelineData }
      );
      useAlert(t('PIPELINES.EDIT.SUCCESS'));
    } else {
      await axios.post(
        `/api/v1/accounts/${accountId.value}/pipelines`,
        { pipeline: pipelineData }
      );
      useAlert(t('PIPELINES.ADD.SUCCESS'));
    }

    router.push({ name: 'pipelines_list' });
  } catch (error) {
    const message = isEditMode.value 
      ? t('PIPELINES.EDIT.ERROR')
      : t('PIPELINES.ADD.ERROR');
    useAlert(message);
  } finally {
    isSaving.value = false;
  }
};

const cancel = () => {
  router.push({ name: 'pipelines_list' });
};

onMounted(() => {
  fetchPipeline();
});
</script>

<template>
  <div class="flex flex-col h-full">
    <!-- Header -->
    <div class="flex items-center justify-between px-6 py-4 border-b border-n-weak bg-n-solid-2">
      <div class="flex items-center gap-3">
        <Button
          icon="i-lucide-arrow-left"
          slate
          faded
          @click="cancel"
        />
        <div>
          <h1 class="text-xl font-semibold text-n-slate-12">
            {{ pageTitle }}
          </h1>
        </div>
      </div>
      <div class="flex gap-2">
        <Button
          :label="$t('PIPELINES.FORM.CANCEL')"
          slate
          @click="cancel"
        />
        <Button
          :label="$t('PIPELINES.FORM.SAVE')"
          :loading="isSaving"
          @click="savePipeline"
        />
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="isLoading" class="flex items-center justify-center flex-1">
      <div class="text-n-slate-11">Loading...</div>
    </div>

    <!-- Form Content -->
    <div v-else class="flex-1 overflow-y-auto p-6">
      <div class="max-w-3xl space-y-6">
        <!-- Name Field -->
        <div>
          <label class="block text-sm font-medium text-n-slate-12 mb-2">
            {{ t('PIPELINES.FORM.NAME_LABEL') }}
            <span class="text-red-500">*</span>
          </label>
          <input
            v-model="pipelineName"
            type="text"
            :placeholder="t('PIPELINES.FORM.NAME_PLACEHOLDER')"
            class="w-full px-3 py-2 border border-n-weak rounded-lg bg-n-solid-2 text-n-slate-12 placeholder-n-slate-10 focus:outline-none focus:border-n-brand"
          />
        </div>

        <!-- Description Field -->
        <div>
          <label class="block text-sm font-medium text-n-slate-12 mb-2">
            {{ t('PIPELINES.FORM.DESCRIPTION_LABEL') }}
          </label>
          <textarea
            v-model="pipelineDescription"
            rows="3"
            :placeholder="t('PIPELINES.FORM.DESCRIPTION_PLACEHOLDER')"
            class="w-full px-3 py-2 border border-n-weak rounded-lg bg-n-solid-2 text-n-slate-12 placeholder-n-slate-10 focus:outline-none focus:border-n-brand resize-none"
          />
        </div>

        <!-- Stages Manager -->
        <StageManager v-model="stages" />
      </div>
    </div>
  </div>
</template>

