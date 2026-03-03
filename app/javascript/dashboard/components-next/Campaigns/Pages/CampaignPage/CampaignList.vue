<script setup>
import { ref } from 'vue';
import CampaignCard from 'dashboard/components-next/Campaigns/CampaignCard/CampaignCard.vue';

defineProps({
  campaigns: { type: Array, required: true },
  isLiveChatType: { type: Boolean, default: false },
});

const emit = defineEmits(['edit', 'viewDetails']);

const expandedId = ref(null);

const handleToggle = id => {
  expandedId.value = expandedId.value === id ? null : id;
};
const handleEdit = campaign => emit('edit', campaign);
const handleViewDetails = campaign => emit('viewDetails', campaign);
</script>

<template>
  <div class="flex flex-col gap-4">
    <CampaignCard
      v-for="campaign in campaigns"
      :id="campaign.id"
      :key="campaign.id"
      :title="campaign.additional_attributes?.email_subject || campaign.title"
      :is-enabled="campaign.enabled"
      :status="campaign.campaign_status"
      :sender="campaign.sender"
      :inbox="campaign.inbox"
      :scheduled-at="campaign.scheduled_at"
      :delivery-report="campaign.delivery_report"
      :is-live-chat-type="isLiveChatType"
      :is-expanded="expandedId === campaign.id"
      @toggle="handleToggle(campaign.id)"
      @edit="handleEdit(campaign)"
      @view-details="handleViewDetails(campaign)"
    />
  </div>
</template>
