<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useStoreGetters, useMapGetter } from 'dashboard/composables/store';

const ITEMS_PER_PAGE = 15;

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CampaignLayout from 'dashboard/components-next/Campaigns/CampaignLayout.vue';
import CampaignList from 'dashboard/components-next/Campaigns/Pages/CampaignPage/CampaignList.vue';
import WhatsAppCampaignCreateDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCampaign/WhatsAppCampaignCreateDialog.vue';
import WhatsAppCampaignEmptyState from 'dashboard/components-next/Campaigns/EmptyState/WhatsAppCampaignEmptyState.vue';
import CampaignNoInboxState from 'dashboard/components-next/Campaigns/EmptyState/CampaignNoInboxState.vue';

const { t } = useI18n();
const router = useRouter();
const getters = useStoreGetters();

const whatsAppInboxes = useMapGetter('inboxes/getWhatsAppInboxes');
const hasWhatsAppCloudInboxes = computed(() =>
  whatsAppInboxes.value?.some(
    inbox => inbox.provider === 'whatsapp_cloud' || inbox.provider === 'twilio'
  )
);

const searchQuery = ref('');
const statusFilter = ref('all');
const inboxFilter = ref('all');
const currentPage = ref(1);

const uiFlags = useMapGetter('campaigns/getUIFlags');
const isFetchingCampaigns = computed(() => uiFlags.value.isFetching);

const createCampaignDialogRef = ref(null);

const whatsAppCampaigns = computed(
  () => getters['campaigns/getWhatsAppCampaigns'].value
);

const statusFilterOptions = computed(() => [
  { label: t('CAMPAIGN.FILTER.ALL'), value: 'all' },
  { label: t('CAMPAIGN.FILTER.COMPLETED'), value: 'completed' },
  { label: t('CAMPAIGN.FILTER.SCHEDULED'), value: 'scheduled' },
  { label: t('CAMPAIGN.FILTER.FAILED'), value: 'failed' },
]);

const statusFilterLabel = computed(() => {
  const option = statusFilterOptions.value.find(
    o => o.value === statusFilter.value
  );
  return option?.label || t('CAMPAIGN.FILTER.ALL');
});

const inboxFilterOptions = computed(() => {
  const campaigns = whatsAppCampaigns.value || [];
  const inboxes = new Map();
  campaigns.forEach(c => {
    if (c.inbox?.id && !inboxes.has(c.inbox.id)) {
      inboxes.set(c.inbox.id, c.inbox.name);
    }
  });
  return [
    { label: t('CAMPAIGN.FILTER.ALL_INBOXES'), value: 'all' },
    ...[...inboxes.entries()].map(([id, name]) => ({
      label: name,
      value: String(id),
    })),
  ];
});

const inboxFilterLabel = computed(() => {
  const option = inboxFilterOptions.value.find(
    o => o.value === inboxFilter.value
  );
  return option?.label || t('CAMPAIGN.FILTER.ALL_INBOXES');
});

const filteredCampaigns = computed(() => {
  let campaigns = whatsAppCampaigns.value || [];

  if (inboxFilter.value !== 'all') {
    campaigns = campaigns.filter(
      c => String(c.inbox?.id) === inboxFilter.value
    );
  }

  if (statusFilter.value !== 'all') {
    campaigns = campaigns.filter(c => {
      if (statusFilter.value === 'completed') {
        return c.campaign_status === 'completed';
      }
      if (statusFilter.value === 'failed') {
        return c.delivery_report?.status === 'completed_with_errors';
      }
      if (statusFilter.value === 'scheduled') {
        return c.campaign_status !== 'completed';
      }
      return true;
    });
  }

  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase();
    campaigns = campaigns.filter(c =>
      (c.title || '').toLowerCase().includes(q)
    );
  }

  return campaigns;
});

const paginatedCampaigns = computed(() => {
  const start = (currentPage.value - 1) * ITEMS_PER_PAGE;
  return filteredCampaigns.value.slice(start, start + ITEMS_PER_PAGE);
});

watch([searchQuery, statusFilter, inboxFilter], () => {
  currentPage.value = 1;
});

const hasNoWhatsAppCampaigns = computed(
  () => whatsAppCampaigns.value?.length === 0 && !isFetchingCampaigns.value
);

const handleCreateCampaign = () => {
  createCampaignDialogRef.value?.openDialog();
};

const handleViewDetails = campaign => {
  router.push({
    name: 'campaigns_whatsapp_detail',
    params: { campaignId: campaign.id },
  });
};

const handleSearch = query => {
  searchQuery.value = query;
};
</script>

<template>
  <CampaignNoInboxState
    v-if="!hasWhatsAppCloudInboxes"
    :title="t('CAMPAIGN.NO_INBOX.WHATSAPP.TITLE')"
    :description="t('CAMPAIGN.NO_INBOX.WHATSAPP.DESCRIPTION')"
    icon="i-ri-whatsapp-line"
  />
  <CampaignLayout
    v-else
    :header-title="t('CAMPAIGN.WHATSAPP.HEADER_TITLE')"
    :button-label="t('CAMPAIGN.WHATSAPP.NEW_CAMPAIGN')"
    :search-query="searchQuery"
    :status-filter="statusFilter"
    :status-filter-options="statusFilterOptions"
    :status-filter-label="statusFilterLabel"
    :inbox-filter="inboxFilter"
    :inbox-filter-options="inboxFilterOptions"
    :inbox-filter-label="inboxFilterLabel"
    :current-page="currentPage"
    :total-items="filteredCampaigns.length"
    @click="handleCreateCampaign"
    @search="handleSearch"
    @update:status-filter="statusFilter = $event"
    @update:inbox-filter="inboxFilter = $event"
    @update:current-page="currentPage = $event"
  >
    <div
      v-if="isFetchingCampaigns"
      class="flex items-center justify-center py-10 text-n-slate-11"
    >
      <Spinner />
    </div>
    <CampaignList
      v-else-if="!hasNoWhatsAppCampaigns"
      :campaigns="paginatedCampaigns"
      @view-details="handleViewDetails"
    />
    <WhatsAppCampaignEmptyState
      v-else
      :title="t('CAMPAIGN.WHATSAPP.EMPTY_STATE.TITLE')"
      :subtitle="t('CAMPAIGN.WHATSAPP.EMPTY_STATE.SUBTITLE')"
      class="pt-14"
    />
    <WhatsAppCampaignCreateDialog ref="createCampaignDialogRef" />
  </CampaignLayout>
</template>
