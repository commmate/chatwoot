<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  pipeline: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['delete']);

const route = useRoute();

const editRoute = computed(() => ({
  name: 'pipelines_edit',
  params: { accountId: route.params.accountId, pipelineId: props.pipeline.id },
}));

const viewBoardRoute = computed(() => ({
  name: 'pipeline_board',
  params: { accountId: route.params.accountId, pipelineId: props.pipeline.id },
}));

const stagesCount = computed(() => props.pipeline.stages?.length || 0);
</script>

<template>
  <tr>
    <td class="py-4 ltr:pr-4 rtl:pl-4">
      <router-link
        :to="viewBoardRoute"
        class="text-n-blue-text hover:underline font-medium"
      >
        {{ pipeline.name }}
      </router-link>
    </td>
    <td class="py-4 ltr:pr-4 rtl:pl-4 text-n-slate-11">
      {{ pipeline.description || '-' }}
    </td>
    <td class="py-4 ltr:pr-4 rtl:pl-4">
      <span class="px-2 py-1 text-xs rounded-full bg-n-alpha-2 text-n-slate-11">
        {{ stagesCount }} stages
      </span>
    </td>
    <td class="py-4 ltr:pr-4 rtl:pl-4">
      <span class="text-n-slate-11">
        {{ pipeline.conversations_count || 0 }}
      </span>
    </td>
    <td class="py-4">
      <div class="flex gap-1 justify-end">
        <router-link :to="viewBoardRoute">
          <Button
            v-tooltip.top="'View Board'"
            icon="i-lucide-kanban-square"
            slate
            xs
            faded
          />
        </router-link>
        <router-link :to="editRoute">
          <Button
            v-tooltip.top="'Edit'"
            icon="i-lucide-pen"
            slate
            xs
            faded
          />
        </router-link>
        <Button
          v-tooltip.top="'Delete'"
          icon="i-lucide-trash-2"
          xs
          ruby
          faded
          @click="emit('delete', pipeline)"
        />
      </div>
    </td>
  </tr>
</template>

