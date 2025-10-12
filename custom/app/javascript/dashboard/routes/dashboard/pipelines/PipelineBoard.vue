<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import axios from 'axios';
import draggable from 'vuedraggable';
import ConversationCard from 'dashboard/components/widgets/conversation/ConversationCard.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import AddConversationModal from './AddConversationModal.vue';

const { t } = useI18n();
const route = useRoute();

const pipeline = ref(null);
const conversations = ref([]);
const isLoading = ref(false);
const showAddModal = ref(false);
const selectedStage = ref(null);

// Filters
const selectedTeam = ref('all');
const selectedInbox = ref('all');
const selectedAgent = ref('all');
const selectedLabel = ref('all');

const accountId = computed(() => route.params.accountId);
const pipelineId = computed(() => route.params.pipelineId);

const fetchPipeline = async () => {
  try {
    const response = await axios.get(
      `/api/v1/accounts/${accountId.value}/pipelines/${pipelineId.value}`
    );
    pipeline.value = response.data;
  } catch (error) {
    console.error('Failed to fetch pipeline:', error);
  }
};

const fetchConversations = async () => {
  if (!pipeline.value) return;

  isLoading.value = true;
  try {
    const params = {
      status: 'open',
      // Add filter params
    };

    if (selectedTeam.value !== 'all') params.team_id = selectedTeam.value;
    if (selectedInbox.value !== 'all') params.inbox_id = selectedInbox.value;
    if (selectedAgent.value !== 'all') params.assignee_id = selectedAgent.value;

    const response = await axios.get(
      `/api/v1/accounts/${accountId.value}/conversations`,
      { params }
    );

    // Filter conversations that have this pipeline's custom field set
    const fieldKey = pipeline.value.custom_field_key;
    const stageNames = pipeline.value.stages.map(s => s.name);
    
    conversations.value = (response.data.data.payload || []).filter(conv => 
      conv.custom_attributes && 
      conv.custom_attributes[fieldKey] &&
      stageNames.includes(conv.custom_attributes[fieldKey])
    );
  } catch (error) {
    console.error('Failed to fetch conversations:', error);
  } finally {
    isLoading.value = false;
  }
};

const getConversationsByStage = (stageName) => {
  if (!pipeline.value) return [];
  
  const fieldKey = pipeline.value.custom_field_key;
  return conversations.value.filter(conv => 
    conv.custom_attributes?.[fieldKey] === stageName
  );
};

const onDrop = async (evt, stage) => {
  if (!evt.added) return;

  const conversation = evt.added.element;
  const fieldKey = pipeline.value.custom_field_key;

  try {
    await axios.patch(
      `/api/v1/accounts/${accountId.value}/conversations/${conversation.id}/custom_attributes`,
      {
        custom_attributes: {
          [fieldKey]: stage.name,
        },
      }
    );
  } catch (error) {
    console.error('Failed to update conversation:', error);
    // Refresh to revert
    fetchConversations();
  }
};

const openAddModal = (stage) => {
  selectedStage.value = stage;
  showAddModal.value = true;
};

const closeAddModal = () => {
  showAddModal.value = false;
  selectedStage.value = null;
};

const onConversationAdded = () => {
  fetchConversations();
  closeAddModal();
};

// Watch filters
watch([selectedTeam, selectedInbox, selectedAgent, selectedLabel], () => {
  fetchConversations();
});

onMounted(async () => {
  await fetchPipeline();
  await fetchConversations();
});
</script>

<template>
  <div class="flex flex-col h-full bg-n-solid-1">
    <!-- Header -->
    <div class="px-6 py-4 bg-n-solid-2 border-b border-n-weak">
      <div class="flex items-center justify-between mb-4">
        <div>
          <h1 class="text-2xl font-semibold text-n-slate-12">
            {{ pipeline?.name || 'Loading...' }}
          </h1>
          <p v-if="pipeline?.description" class="text-sm text-n-slate-11 mt-1">
            {{ pipeline.description }}
          </p>
        </div>
        <div class="text-sm text-n-slate-11">
          {{ conversations.length }} conversations
        </div>
      </div>

      <!-- Filters -->
      <div class="flex gap-3">
        <select
          v-model="selectedTeam"
          class="px-3 py-1.5 text-sm border border-n-weak rounded-lg bg-n-solid-3 text-n-slate-12"
        >
          <option value="all">All Teams</option>
        </select>

        <select
          v-model="selectedInbox"
          class="px-3 py-1.5 text-sm border border-n-weak rounded-lg bg-n-solid-3 text-n-slate-12"
        >
          <option value="all">All Inboxes</option>
        </select>

        <select
          v-model="selectedAgent"
          class="px-3 py-1.5 text-sm border border-n-weak rounded-lg bg-n-solid-3 text-n-slate-12"
        >
          <option value="all">All Agents</option>
        </select>

        <select
          v-model="selectedLabel"
          class="px-3 py-1.5 text-sm border border-n-weak rounded-lg bg-n-solid-3 text-n-slate-12"
        >
          <option value="all">All Labels</option>
        </select>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="isLoading || !pipeline" class="flex items-center justify-center flex-1">
      <Spinner />
    </div>

    <!-- Pipeline Board -->
    <div v-else class="flex flex-1 gap-4 p-6 overflow-x-auto bg-n-solid-1">
      <div
        v-for="stage in pipeline.stages"
        :key="stage.order"
        class="flex flex-col w-80 flex-shrink-0"
      >
        <!-- Column Header -->
        <div class="flex items-center justify-between px-4 py-3 mb-3 rounded-lg border bg-n-solid-2 border-n-weak">
          <div class="flex items-center gap-2">
            <h3 class="text-sm font-semibold text-n-slate-12">
              {{ stage.name }}
            </h3>
          </div>
          <div class="flex items-center gap-2">
            <span class="px-2 py-0.5 text-xs font-medium rounded-full bg-n-alpha-2 text-n-slate-11">
              {{ getConversationsByStage(stage.name).length }}
            </span>
            <Button
              icon="i-lucide-plus"
              size="xs"
              slate
              faded
              @click="openAddModal(stage)"
            />
          </div>
        </div>

        <!-- Droppable Area -->
        <draggable
          :model-value="getConversationsByStage(stage.name)"
          :group="{ name: 'pipeline-conversations', pull: true, put: true }"
          class="flex-1 p-2 space-y-2 overflow-y-auto rounded-lg border bg-n-solid-2 border-n-weak min-h-[200px]"
          item-key="id"
          :animation="200"
          ghost-class="opacity-50"
          @change="(evt) => onDrop(evt, stage)"
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
              v-if="getConversationsByStage(stage.name).length === 0"
              class="flex flex-col items-center justify-center py-8 text-sm text-n-slate-10"
            >
              <Icon icon="i-lucide-inbox" class="size-8 mb-2 text-n-slate-9" />
              <p>{{ t('PIPELINES.BOARD.EMPTY_STAGE') }}</p>
            </div>
          </template>
        </draggable>
      </div>
    </div>

    <!-- Add Conversation Modal -->
    <AddConversationModal
      v-if="showAddModal && selectedStage"
      :show="showAddModal"
      :pipeline="pipeline"
      :stage="selectedStage"
      :account-id="accountId"
      @close="closeAddModal"
      @added="onConversationAdded"
    />
  </div>
</template>

