<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import draggable from 'vuedraggable';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  modelValue: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const localStages = computed({
  get: () => props.modelValue,
  set: (value) => {
    // Update order property when dragged
    const orderedStages = value.map((stage, index) => ({
      ...stage,
      order: index,
    }));
    emit('update:modelValue', orderedStages);
  },
});

const newStageName = ref('');

const addStage = () => {
  if (!newStageName.value.trim()) return;

  const newStage = {
    name: newStageName.value.trim(),
    order: localStages.value.length,
  };

  emit('update:modelValue', [...localStages.value, newStage]);
  newStageName.value = '';
};

const removeStage = (index) => {
  const updatedStages = localStages.value.filter((_, i) => i !== index);
  // Reorder after removal
  const reordered = updatedStages.map((stage, idx) => ({
    ...stage,
    order: idx,
  }));
  emit('update:modelValue', reordered);
};
</script>

<template>
  <div class="space-y-4">
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{ t('PIPELINES.FORM.STAGES_LABEL') }}
      </label>
      <p class="text-sm text-n-slate-11 mb-3">
        {{ t('PIPELINES.FORM.STAGES_DESCRIPTION') }}
      </p>
    </div>

    <!-- Draggable Stage List -->
    <draggable
      v-model="localStages"
      item-key="order"
      handle=".drag-handle"
      :animation="200"
      class="space-y-2"
    >
      <template #item="{ element, index }">
        <div
          class="flex items-center gap-3 p-3 rounded-lg border border-n-weak bg-n-solid-2 hover:border-n-alpha-4"
        >
          <Icon
            icon="i-lucide-grip-vertical"
            class="size-4 text-n-slate-10 cursor-move drag-handle"
          />
          <span class="px-2 py-1 text-xs rounded bg-n-alpha-2 text-n-slate-11 font-medium min-w-[2rem] text-center">
            {{ index + 1 }}
          </span>
          <span class="flex-grow text-sm text-n-slate-12 font-medium">
            {{ element.name }}
          </span>
          <Button
            icon="i-lucide-trash-2"
            size="xs"
            ruby
            faded
            @click="removeStage(index)"
          />
        </div>
      </template>
    </draggable>

    <!-- Empty State -->
    <div
      v-if="!localStages.length"
      class="p-6 text-center border border-dashed border-n-weak rounded-lg bg-n-solid-1"
    >
      <Icon icon="i-lucide-list-ordered" class="size-8 text-n-slate-10 mx-auto mb-2" />
      <p class="text-sm text-n-slate-11">
        {{ t('PIPELINES.FORM.NO_STAGES') }}
      </p>
    </div>

    <!-- Add Stage Input -->
    <div class="flex gap-2">
      <input
        v-model="newStageName"
        type="text"
        :placeholder="t('PIPELINES.FORM.STAGE_PLACEHOLDER')"
        class="flex-grow px-3 py-2 text-sm border border-n-weak rounded-lg bg-n-solid-2 text-n-slate-12 placeholder-n-slate-10 focus:outline-none focus:border-n-brand"
        @keyup.enter="addStage"
      />
      <Button
        icon="i-lucide-plus"
        :label="t('PIPELINES.FORM.ADD_STAGE')"
        @click="addStage"
      />
    </div>
  </div>
</template>

