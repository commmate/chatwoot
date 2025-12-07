<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import PipelinesAPI from '../../../../api/pipelines';
import StageManager from './StageManager.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();

const props = defineProps({
  pipeline: {
    type: Object,
    default: null,
  },
  onClose: {
    type: Function,
    default: () => {},
  },
});

const emit = defineEmits(['save']);

const pipelineName = ref('');
const pipelineDescription = ref('');
const stages = ref([]);
const isSaving = ref(false);

const isEditMode = computed(() => !!props.pipeline);

const modalTitle = computed(() =>
  isEditMode.value ? t('PIPELINES.EDIT.TITLE') : t('PIPELINES.ADD.TITLE')
);

const loadPipeline = () => {
  if (props.pipeline) {
    pipelineName.value = props.pipeline.name || '';
    pipelineDescription.value = props.pipeline.description || '';
    stages.value = props.pipeline.stages || [];
  } else {
    pipelineName.value = '';
    pipelineDescription.value = '';
    stages.value = [];
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
      await PipelinesAPI.update(props.pipeline.id, pipelineData);
      useAlert(t('PIPELINES.EDIT.SUCCESS'));
    } else {
      await PipelinesAPI.create(pipelineData);
      useAlert(t('PIPELINES.ADD.SUCCESS'));
    }

    emit('save');
  } catch (error) {
    const message = isEditMode.value
      ? t('PIPELINES.EDIT.ERROR')
      : t('PIPELINES.ADD.ERROR');
    useAlert(message);
  } finally {
    isSaving.value = false;
  }
};

onMounted(() => {
  loadPipeline();
});
</script>

<template>
  <div>
    <woot-modal-header :header-title="modalTitle" />
    <div class="flex flex-col modal-content">
      <div class="w-full space-y-4">
        <!-- Name Field -->
        <woot-input
          v-model="pipelineName"
          :label="t('PIPELINES.FORM.NAME_LABEL')"
          type="text"
          :placeholder="t('PIPELINES.FORM.NAME_PLACEHOLDER')"
        />

        <!-- Description Field -->
        <woot-input
          v-model="pipelineDescription"
          :label="t('PIPELINES.FORM.DESCRIPTION_LABEL')"
          type="text"
          :placeholder="t('PIPELINES.FORM.DESCRIPTION_PLACEHOLDER')"
        />

        <!-- Stages Manager -->
        <StageManager v-model="stages" />

        <!-- Modal Footer -->
        <div class="w-full">
          <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
            <NextButton
              faded
              slate
              :label="$t('PIPELINES.FORM.CANCEL')"
              @click="onClose"
            />
            <NextButton
              solid
              blue
              :is-loading="isSaving"
              :label="$t('PIPELINES.FORM.SAVE')"
              @click="savePipeline"
            />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
