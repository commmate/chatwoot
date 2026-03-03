<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import { useStoreGetters, useMapGetter } from 'dashboard/composables/store';

const ITEMS_PER_PAGE = 15;

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CampaignLayout from 'dashboard/components-next/Campaigns/CampaignLayout.vue';
import CampaignList from 'dashboard/components-next/Campaigns/Pages/CampaignPage/CampaignList.vue';
import LiveChatCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/LiveChatCampaign/LiveChatCampaignDialog.vue';
import EditLiveChatCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/LiveChatCampaign/EditLiveChatCampaignDialog.vue';
import ConfirmDeleteCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/ConfirmDeleteCampaignDialog.vue';
import LiveChatCampaignEmptyState from 'dashboard/components-next/Campaigns/EmptyState/LiveChatCampaignEmptyState.vue';
import CampaignNoInboxState from 'dashboard/components-next/Campaigns/EmptyState/CampaignNoInboxState.vue';

const { t } = useI18n();
const getters = useStoreGetters();

const websiteInboxes = useMapGetter('inboxes/getWebsiteInboxes');
const hasWebsiteInboxes = computed(() => websiteInboxes.value?.length > 0);

const editLiveChatCampaignDialogRef = ref(null);
const confirmDeleteCampaignDialogRef = ref(null);
const selectedCampaign = ref(null);
const searchQuery = ref('');
const currentPage = ref(1);

const uiFlags = useMapGetter('campaigns/getUIFlags');
const isFetchingCampaigns = computed(() => uiFlags.value.isFetching);

const [showLiveChatCampaignDialog, toggleLiveChatCampaignDialog] = useToggle();

const liveChatCampaigns = computed(
  () => getters['campaigns/getLiveChatCampaigns'].value
);

const filteredCampaigns = computed(() => {
  if (!searchQuery.value) return liveChatCampaigns.value;
  const q = searchQuery.value.toLowerCase();
  return liveChatCampaigns.value?.filter(c =>
    (c.title || '').toLowerCase().includes(q)
  );
});

const paginatedCampaigns = computed(() => {
  const list = filteredCampaigns.value || [];
  const start = (currentPage.value - 1) * ITEMS_PER_PAGE;
  return list.slice(start, start + ITEMS_PER_PAGE);
});

watch(searchQuery, () => {
  currentPage.value = 1;
});

const hasNoLiveChatCampaigns = computed(
  () => liveChatCampaigns.value?.length === 0 && !isFetchingCampaigns.value
);

const handleEdit = campaign => {
  selectedCampaign.value = campaign;
  editLiveChatCampaignDialogRef.value.dialogRef.open();
};

const handleDelete = campaign => {
  selectedCampaign.value = campaign;
  confirmDeleteCampaignDialogRef.value.dialogRef.open();
};

const handleSearch = query => {
  searchQuery.value = query;
};
</script>

<template>
  <CampaignNoInboxState
    v-if="!hasWebsiteInboxes"
    :title="t('CAMPAIGN.NO_INBOX.LIVE_CHAT.TITLE')"
    :description="t('CAMPAIGN.NO_INBOX.LIVE_CHAT.DESCRIPTION')"
    icon="i-lucide-message-circle"
  />
  <CampaignLayout
    v-else
    :header-title="t('CAMPAIGN.LIVE_CHAT.HEADER_TITLE')"
    :button-label="t('CAMPAIGN.LIVE_CHAT.NEW_CAMPAIGN')"
    :search-query="searchQuery"
    :show-status-filter="false"
    :current-page="currentPage"
    :total-items="(filteredCampaigns || []).length"
    @click="toggleLiveChatCampaignDialog()"
    @close="toggleLiveChatCampaignDialog(false)"
    @search="handleSearch"
    @update:current-page="currentPage = $event"
  >
    <template #action>
      <LiveChatCampaignDialog
        v-if="showLiveChatCampaignDialog"
        @close="toggleLiveChatCampaignDialog(false)"
      />
    </template>

    <div
      v-if="isFetchingCampaigns"
      class="flex justify-center items-center py-10 text-n-slate-11"
    >
      <Spinner />
    </div>
    <CampaignList
      v-else-if="!hasNoLiveChatCampaigns"
      :campaigns="paginatedCampaigns"
      is-live-chat-type
      @edit="handleEdit"
      @delete="handleDelete"
    />
    <LiveChatCampaignEmptyState
      v-else
      :title="t('CAMPAIGN.LIVE_CHAT.EMPTY_STATE.TITLE')"
      :subtitle="t('CAMPAIGN.LIVE_CHAT.EMPTY_STATE.SUBTITLE')"
      class="pt-14"
    />
    <EditLiveChatCampaignDialog
      ref="editLiveChatCampaignDialogRef"
      :selected-campaign="selectedCampaign"
    />
    <ConfirmDeleteCampaignDialog
      ref="confirmDeleteCampaignDialogRef"
      :selected-campaign="selectedCampaign"
    />
  </CampaignLayout>
</template>
