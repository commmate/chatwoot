<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import { useStoreGetters, useMapGetter } from 'dashboard/composables/store';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CampaignLayout from 'dashboard/components-next/Campaigns/CampaignLayout.vue';
import CampaignList from 'dashboard/components-next/Campaigns/Pages/CampaignPage/CampaignList.vue';
import EmailCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/EmailCampaign/EmailCampaignDialog.vue';
import ConfirmDeleteCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/ConfirmDeleteCampaignDialog.vue';
import EmailCampaignDetailsDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/EmailCampaign/EmailCampaignDetailsDialog.vue';
import EmailCampaignEmptyState from 'dashboard/components-next/Campaigns/EmptyState/EmailCampaignEmptyState.vue';
import CampaignNoInboxState from 'dashboard/components-next/Campaigns/EmptyState/CampaignNoInboxState.vue';

const { t } = useI18n();
const getters = useStoreGetters();

// Check for Resend email inboxes
const resendInboxes = useMapGetter('inboxes/getResendInboxes');
const hasResendInboxes = computed(() => resendInboxes.value?.length > 0);

const selectedCampaign = ref(null);
const [showDeliveryReportDialog, toggleDeliveryReportDialog] = useToggle();

const uiFlags = useMapGetter('campaigns/getUIFlags');
const isFetchingCampaigns = computed(() => uiFlags.value.isFetching);

const confirmDeleteCampaignDialogRef = ref(null);
const createCampaignDialogRef = ref(null);

const emailCampaigns = computed(
  () => getters['campaigns/getEmailCampaigns'].value
);

const hasNoEmailCampaigns = computed(
  () => emailCampaigns.value?.length === 0 && !isFetchingCampaigns.value
);

const handleCreateCampaign = () => {
  createCampaignDialogRef.value?.openDialog();
};

const handleDelete = campaign => {
  selectedCampaign.value = campaign;
  confirmDeleteCampaignDialogRef.value.dialogRef.open();
};

const handleView = campaign => {
  selectedCampaign.value = campaign;
  toggleDeliveryReportDialog(true);
};

const handleCloseDetails = () => {
  toggleDeliveryReportDialog(false);
  selectedCampaign.value = null;
};
</script>

<template>
  <CampaignNoInboxState
    v-if="!hasResendInboxes"
    :title="t('CAMPAIGN.NO_INBOX.EMAIL.TITLE')"
    :description="t('CAMPAIGN.NO_INBOX.EMAIL.DESCRIPTION')"
    icon="i-ri-mail-line"
  />
  <CampaignLayout
    v-else
    :header-title="t('CAMPAIGN.EMAIL.HEADER_TITLE')"
    :button-label="t('CAMPAIGN.EMAIL.NEW_CAMPAIGN')"
    @click="handleCreateCampaign"
  >
    <div
      v-if="isFetchingCampaigns"
      class="flex items-center justify-center py-10 text-n-slate-11"
    >
      <Spinner />
    </div>
    <CampaignList
      v-else-if="!hasNoEmailCampaigns"
      :campaigns="emailCampaigns"
      @delete="handleDelete"
      @view="handleView"
    />
    <EmailCampaignEmptyState
      v-else
      :title="t('CAMPAIGN.EMAIL.EMPTY_STATE.TITLE')"
      :subtitle="t('CAMPAIGN.EMAIL.EMPTY_STATE.SUBTITLE')"
      class="pt-14"
    />
    <EmailCampaignDialog ref="createCampaignDialogRef" />
    <ConfirmDeleteCampaignDialog
      ref="confirmDeleteCampaignDialogRef"
      :selected-campaign="selectedCampaign"
    />
    <EmailCampaignDetailsDialog
      :is-open="showDeliveryReportDialog"
      :campaign="selectedCampaign"
      @close="handleCloseDetails"
    />
  </CampaignLayout>
</template>
