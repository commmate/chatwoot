/* global axios */
<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import ConversationApi from 'dashboard/api/conversations';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  show: Boolean,
  pipeline: Object,
  stage: Object,
  accountId: [String, Number],
});

const emit = defineEmits(['close', 'added']);

const { t } = useI18n();

const availableConversations = ref([]);
const selectedConversations = ref([]);
const isLoading = ref(false);
const isSaving = ref(false);
const searchQuery = ref('');

const filteredConversations = computed(() => {
  if (!searchQuery.value) return availableConversations.value;
  
  const query = searchQuery.value.toLowerCase();
  return availableConversations.value.filter(conv => 
    conv.meta?.sender?.name?.toLowerCase().includes(query) ||
    conv.display_id?.toString().includes(query)
  );
});

const fetchAvailableConversations = async () => {
  isLoading.value = true;
  try {
    const response = await ConversationApi.get({ status: 'open' });

    const fieldKey = props.pipeline.custom_field_key;
    
    // Only show conversations that don't have this pipeline field set
    availableConversations.value = (response.data.data.payload || []).filter(conv =>
      !conv.custom_attributes || !conv.custom_attributes[fieldKey]
    );
  } catch (error) {
    console.error('Failed to fetch conversations:', error);
  } finally {
    isLoading.value = false;
  }
};

const toggleConversation = (conversationId) => {
  const index = selectedConversations.value.indexOf(conversationId);
  if (index > -1) {
    selectedConversations.value.splice(index, 1);
  } else {
    selectedConversations.value.push(conversationId);
  }
};

const isSelected = (conversationId) => {
  return selectedConversations.value.includes(conversationId);
};

const addConversations = async () => {
  if (!selectedConversations.value.length) return;

  isSaving.value = true;
  try {
    const fieldKey = props.pipeline.custom_field_key;
    
    // Update each selected conversation
    await Promise.all(
      selectedConversations.value.map(conversationId =>
        axios.patch(
          `/api/v1/accounts/${props.accountId}/conversations/${conversationId}/custom_attributes`,
          {
            custom_attributes: {
              [fieldKey]: props.stage.name,
            },
          }
        )
      )
    );

    useAlert(t('PIPELINES.BOARD.ADD_SUCCESS', { count: selectedConversations.value.length }));
    emit('added');
  } catch (error) {
    useAlert(t('PIPELINES.BOARD.ADD_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

onMounted(() => {
  fetchAvailableConversations();
});
</script>

<template>
  <woot-modal
    :show="show"
    :on-close="() => emit('close')"
  >
    <div class="flex flex-col h-[600px]">
      <!-- Header -->
      <div class="px-6 py-4 border-b border-n-weak">
        <h2 class="text-lg font-semibold text-n-slate-12">
          {{ t('PIPELINES.BOARD.ADD_TO_STAGE', { stage: stage.name }) }}
        </h2>
        <p class="text-sm text-n-slate-11 mt-1">
          {{ t('PIPELINES.BOARD.ADD_DESCRIPTION') }}
        </p>
      </div>

      <!-- Search -->
      <div class="px-6 py-3 border-b border-n-weak">
        <input
          v-model="searchQuery"
          type="text"
          :placeholder="t('PIPELINES.BOARD.SEARCH_PLACEHOLDER')"
          class="w-full px-3 py-2 text-sm border border-n-weak rounded-lg bg-n-solid-2 text-n-slate-12 placeholder-n-slate-10"
        />
      </div>

      <!-- Conversation List -->
      <div class="flex-1 overflow-y-auto px-6 py-4">
        <div v-if="isLoading" class="flex items-center justify-center py-8">
          <Spinner />
        </div>

        <div v-else-if="!filteredConversations.length" class="flex flex-col items-center justify-center py-8">
          <Icon icon="i-lucide-inbox" class="size-12 text-n-slate-10 mb-2" />
          <p class="text-sm text-n-slate-11">
            {{ t('PIPELINES.BOARD.NO_AVAILABLE_CONVERSATIONS') }}
          </p>
        </div>

        <div v-else class="space-y-2">
          <div
            v-for="conv in filteredConversations"
            :key="conv.id"
            class="flex items-center gap-3 p-3 rounded-lg border border-n-weak hover:border-n-alpha-4 cursor-pointer transition-all"
            :class="{ 'bg-n-brand/5 border-n-brand': isSelected(conv.id) }"
            @click="toggleConversation(conv.id)"
          >
            <input
              type="checkbox"
              :checked="isSelected(conv.id)"
              class="size-4"
            />
            <div class="flex-grow min-w-0">
              <div class="text-sm font-medium text-n-slate-12">
                #{{ conv.display_id }} - {{ conv.meta?.sender?.name || 'Unknown' }}
              </div>
              <div class="text-xs text-n-slate-11 truncate">
                {{ conv.messages?.[0]?.content || 'No messages' }}
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div class="px-6 py-4 border-t border-n-weak flex justify-end gap-2">
        <Button
          :label="t('PIPELINES.BOARD.CANCEL')"
          slate
          @click="emit('close')"
        />
        <Button
          :label="t('PIPELINES.BOARD.ADD_SELECTED', { count: selectedConversations.length })"
          :disabled="!selectedConversations.length"
          :loading="isSaving"
          @click="addConversations"
        />
      </div>
    </div>
  </woot-modal>
</template>

