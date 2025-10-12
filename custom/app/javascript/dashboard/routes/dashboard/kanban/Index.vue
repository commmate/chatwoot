<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import axios from 'axios';
import draggable from 'vuedraggable';
import ConversationCard from 'dashboard/components/widgets/conversation/ConversationCard.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n();
const store = useStore();
const route = useRoute();

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

// Kanban board maintains its own conversation state
// This prevents interfering with the main conversation list
const conversations = ref([]);
const isLoading = ref(false);

const getConversationsByStatus = (statusString) => {
  return conversations.value.filter(conv => conv.status === statusString);
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
    await store.dispatch('toggleStatus', {
      conversationId: conversation.id,
      status: newStatus,
    });
  } catch (error) {
    console.error('Failed to update conversation status:', error);
  }
};

const fetchKanbanConversations = async () => {
  isLoading.value = true;
  try {
    const accountId = route.params.accountId;
    
    // Fetch conversations for each status independently
    const statuses = ['open', 'pending', 'snoozed', 'resolved'];
    const promises = statuses.map(status =>
      axios.get(`/api/v1/accounts/${accountId}/conversations`, {
        params: { status }
      })
    );
    
    const results = await Promise.all(promises);
    const allConvs = results.flatMap(response => response.data.data.payload || []);
    
    conversations.value = allConvs;
    console.log('Kanban - Loaded conversations:', allConvs.length);
  } catch (error) {
    console.error('Kanban - Failed to fetch:', error);
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  fetchKanbanConversations();
});
</script>

<template>
  <div class="flex flex-col h-full bg-n-solid-1">
    <!-- Header -->
    <div class="flex items-center justify-between px-6 py-4 bg-n-solid-2 border-b border-n-weak">
      <div>
        <h1 class="text-2xl font-semibold text-n-slate-12">
          {{ t('KANBAN.TITLE') }}
        </h1>
        <p class="text-sm text-n-slate-11">
          {{ t('KANBAN.DESCRIPTION') }}
        </p>
      </div>
      <div class="text-sm text-n-slate-11">
        {{ conversations.length }} {{ t('KANBAN.TOTAL_CONVERSATIONS') }}
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="isLoading" class="flex items-center justify-center flex-1">
      <Spinner />
    </div>

    <!-- Kanban Board -->
    <div v-else class="flex flex-1 gap-4 p-6 overflow-x-auto bg-n-solid-1">
      <div
        v-for="column in columns"
        :key="column.id"
        class="flex flex-col w-80 flex-shrink-0"
      >
        <!-- Column Header -->
        <div 
          class="flex items-center justify-between px-4 py-3 mb-3 rounded-lg border bg-n-solid-2 border-n-weak"
        >
          <div class="flex items-center gap-2">
            <Icon :icon="column.icon" class="size-5 text-n-slate-11" />
            <h3 class="text-sm font-semibold text-n-slate-12">
              {{ t(column.title) }}
            </h3>
          </div>
          <span 
            class="px-2 py-0.5 text-xs font-medium rounded-full bg-n-alpha-2 text-n-slate-11"
          >
            {{ getConversationsByStatus(column.status).length }}
          </span>
        </div>

        <!-- Droppable Area -->
        <draggable
          :model-value="getConversationsByStatus(column.status)"
          :group="{ name: 'conversations', pull: true, put: true }"
          class="flex-1 p-2 space-y-2 overflow-y-auto rounded-lg border bg-n-solid-2 border-n-weak min-h-[200px]"
          item-key="id"
          :animation="200"
          ghost-class="opacity-50"
          @change="(evt) => onDrop(evt, column)"
        >
          <template #item="{ element }">
            <div class="bg-n-solid-3 rounded-lg border border-n-weak hover:border-n-alpha-4 transition-all duration-200 cursor-move">
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
              v-if="getConversationsByStatus(column.status).length === 0"
              class="flex items-center justify-center py-8 text-sm text-n-slate-10"
            >
              {{ t('KANBAN.EMPTY_COLUMN') }}
            </div>
          </template>
        </draggable>
      </div>
    </div>
  </div>
</template>

