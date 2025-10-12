<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import draggable from 'vuedraggable';
import ConversationCard from 'dashboard/components/widgets/conversation/ConversationCard.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n();
const store = useStore();

const columns = ref([
  { 
    id: 'open', 
    title: 'KANBAN.COLUMNS.OPEN', 
    status: 'open', 
    statusValue: 0,
    color: 'blue',
    icon: 'i-lucide-circle-dot'
  },
  { 
    id: 'pending', 
    title: 'KANBAN.COLUMNS.PENDING', 
    status: 'pending', 
    statusValue: 2,
    color: 'yellow',
    icon: 'i-lucide-clock'
  },
  { 
    id: 'snoozed', 
    title: 'KANBAN.COLUMNS.SNOOZED', 
    status: 'snoozed', 
    statusValue: 3,
    color: 'purple',
    icon: 'i-lucide-moon'
  },
  { 
    id: 'resolved', 
    title: 'KANBAN.COLUMNS.RESOLVED', 
    status: 'resolved', 
    statusValue: 1,
    color: 'green',
    icon: 'i-lucide-check-circle'
  },
]);

const isLoading = computed(() => 
  store.getters['conversations/getUIFlags'].isFetchingList
);

const allConversations = computed(() => 
  store.getters['conversations/getAllConversations']
);

const getConversationsByStatus = (statusValue) => {
  return allConversations.value.filter(conv => conv.status === statusValue);
};

const getColumnColor = (color) => {
  const colors = {
    blue: 'bg-blue-50 border-blue-200',
    yellow: 'bg-yellow-50 border-yellow-200',
    purple: 'bg-purple-50 border-purple-200',
    green: 'bg-green-50 border-green-200',
  };
  return colors[color] || 'bg-slate-50 border-slate-200';
};

const getColumnHeaderColor = (color) => {
  const colors = {
    blue: 'bg-blue-100 text-blue-900',
    yellow: 'bg-yellow-100 text-yellow-900',
    purple: 'bg-purple-100 text-purple-900',
    green: 'bg-green-100 text-green-900',
  };
  return colors[color] || 'bg-slate-100 text-slate-900';
};

const onDrop = async (evt, column) => {
  if (!evt.added) return;
  
  const conversation = evt.added.element;
  const newStatus = column.status;
  
  try {
    await store.dispatch('conversations/toggleStatus', {
      conversationId: conversation.id,
      status: newStatus,
    });
  } catch (error) {
    console.error('Failed to update conversation status:', error);
  }
};

onMounted(() => {
  // Fetch conversations if not already loaded
  if (allConversations.value.length === 0) {
    store.dispatch('fetchAllConversations');
  }
});
</script>

<template>
  <div class="flex flex-col h-full bg-slate-50">
    <!-- Header -->
    <div class="flex items-center justify-between px-6 py-4 bg-white border-b border-slate-200">
      <div>
        <h1 class="text-2xl font-semibold text-slate-900">
          {{ t('KANBAN.TITLE') }}
        </h1>
        <p class="text-sm text-slate-600">
          {{ t('KANBAN.DESCRIPTION') }}
        </p>
      </div>
      <div class="text-sm text-slate-600">
        {{ allConversations.length }} {{ t('KANBAN.TOTAL_CONVERSATIONS') }}
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="isLoading" class="flex items-center justify-center flex-1">
      <Spinner />
    </div>

    <!-- Kanban Board -->
    <div v-else class="flex flex-1 gap-4 p-6 overflow-x-auto">
      <div
        v-for="column in columns"
        :key="column.id"
        class="flex flex-col w-80 flex-shrink-0"
      >
        <!-- Column Header -->
        <div 
          class="flex items-center justify-between px-4 py-3 mb-3 rounded-lg border"
          :class="getColumnHeaderColor(column.color)"
        >
          <div class="flex items-center gap-2">
            <Icon :icon="column.icon" class="size-5" />
            <h3 class="text-sm font-semibold">
              {{ t(column.title) }}
            </h3>
          </div>
          <span 
            class="px-2 py-0.5 text-xs font-medium rounded-full bg-white/60"
          >
            {{ getConversationsByStatus(column.statusValue).length }}
          </span>
        </div>

        <!-- Droppable Area -->
        <draggable
          :model-value="getConversationsByStatus(column.statusValue)"
          :group="{ name: 'conversations', pull: true, put: true }"
          class="flex-1 p-2 space-y-2 overflow-y-auto rounded-lg border min-h-[200px]"
          :class="getColumnColor(column.color)"
          item-key="id"
          :animation="200"
          ghost-class="opacity-50"
          @change="(evt) => onDrop(evt, column)"
        >
          <template #item="{ element }">
            <div class="bg-white rounded-lg shadow-sm hover:shadow-md transition-all duration-200 cursor-move">
              <ConversationCard
                :chat="element"
                :hide-inbox-name="false"
                compact
              />
            </div>
          </template>
          
          <!-- Empty State -->
          <template #footer>
            <div 
              v-if="getConversationsByStatus(column.statusValue).length === 0"
              class="flex items-center justify-center py-8 text-sm text-slate-500"
            >
              {{ t('KANBAN.EMPTY_COLUMN') }}
            </div>
          </template>
        </draggable>
      </div>
    </div>
  </div>
</template>

