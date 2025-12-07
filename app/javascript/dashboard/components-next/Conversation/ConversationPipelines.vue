<script setup>
import { computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  conversationId: {
    type: Number,
    required: true,
  },
});
const store = useStore();
const { t } = useI18n();

// Get conversation data
const conversation = computed(() =>
  store.getters['conversationDetails/getConversation'](props.conversationId)
);

// Get all account pipelines
const accountPipelines = computed(
  () => store.getters['pipelines/getPipelines'] || []
);

// Get current user
const currentUser = computed(() => store.getters.getCurrentUser);

// Check if user can manage pipelines (required to see this section)
const canManagePipelines = computed(() => {
  const { role, custom_role } = currentUser.value;

  // Administrator always can
  if (role === 'administrator') return true;

  // Check custom role permission
  if (custom_role?.permissions) {
    return custom_role.permissions.includes('pipeline_manage');
  }

  return false;
});

// Show section ONLY if user has pipeline_manage permission
// Hidden completely if no permission (even if conversation is in pipeline)
const showPipelinesSection = computed(() => {
  return canManagePipelines.value;
});

// Separate pipeline fields from regular custom attributes
const pipelineFields = computed(() => {
  const customAttributes = conversation.value?.custom_attributes || {};
  const pipelines = [];

  // Get all pipeline field keys
  const pipelineFieldKeys = accountPipelines.value
    .map(p => p.custom_field_key)
    .filter(Boolean);

  // Extract pipeline fields
  Object.entries(customAttributes).forEach(([key, value]) => {
    if (pipelineFieldKeys.includes(key)) {
      const pipeline = accountPipelines.value.find(
        p => p.custom_field_key === key
      );
      if (pipeline) {
        pipelines.push({
          key,
          value,
          pipeline,
          pipelineName: pipeline.name,
          currentStage: value,
        });
      }
    }
  });

  return pipelines;
});

// Update pipeline stage
const updatePipelineStage = async (fieldKey, stageName) => {
  try {
    // Update conversation custom attribute
    await store.dispatch('conversationAttributes/update', {
      conversationId: props.conversationId,
      customAttributes: {
        [fieldKey]: stageName || null,
      },
    });

    // Show success message
    store.dispatch('emitter/newToastMessage', {
      message: t('PIPELINES.STAGE_UPDATED'),
      type: 'success',
    });
  } catch (error) {
    // Show error message
    store.dispatch('emitter/newToastMessage', {
      message: t('PIPELINES.UPDATE_FAILED'),
      type: 'error',
    });
  }
};
</script>

<template>
  <div>
    <div
      v-if="showPipelinesSection"
      class="conversation-pipelines bg-slate-25 dark:bg-slate-900 rounded-lg p-4 mb-4"
    >
      <!-- Section Header -->
      <div class="flex items-center gap-2 mb-3">
        <i class="i-lucide-git-branch text-lg text-woot-500" />
        <h3 class="text-sm font-medium text-slate-900 dark:text-slate-100">
          {{ $t('PIPELINES.SECTION_TITLE') }}
        </h3>
      </div>

      <!-- Pipeline Cards -->
      <div v-if="pipelineFields.length > 0" class="space-y-2">
        <div
          v-for="pipelineField in pipelineFields"
          :key="pipelineField.key"
          class="pipeline-card bg-woot-50 dark:bg-slate-800 rounded-lg p-3 border border-woot-200 dark:border-slate-700 transition-all hover:shadow-sm"
        >
          <!-- Pipeline Name -->
          <div
            class="text-xs font-medium text-slate-600 dark:text-slate-400 mb-2"
          >
            {{ pipelineField.pipelineName }}
          </div>

          <!-- Stage Selector (always editable if section is visible) -->
          <select
            :value="pipelineField.currentStage"
            class="w-full px-3 py-2 text-sm border border-slate-200 dark:border-slate-700 rounded-md bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 focus:ring-2 focus:ring-woot-500 focus:border-transparent"
            @change="
              updatePipelineStage(pipelineField.key, $event.target.value)
            "
          >
            <option value="">{{ $t('PIPELINES.NO_STAGE') }}</option>
            <option
              v-for="stage in pipelineField.pipeline.stages"
              :key="stage.name"
              :value="stage.name"
            >
              {{ stage.name }}
            </option>
          </select>
        </div>
      </div>

      <!-- Empty State -->
      <div
        v-else
        class="text-sm text-slate-500 dark:text-slate-400 text-center py-4"
      >
        {{ $t('PIPELINES.NOT_IN_PIPELINE') }}
      </div>
    </div>
  </div>
</template>

<style scoped>
.conversation-pipelines {
  @apply transition-all;
}

.pipeline-card {
  @apply transition-shadow;
}
</style>
