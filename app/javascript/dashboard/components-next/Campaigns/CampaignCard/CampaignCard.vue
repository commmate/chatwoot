<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { getInboxIconByType } from 'dashboard/helper/inbox';
import { format, fromUnixTime } from 'date-fns';

import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  id: { type: Number, required: true },
  title: { type: String, default: '' },
  isLiveChatType: { type: Boolean, default: false },
  isEnabled: { type: Boolean, default: false },
  status: { type: String, default: '' },
  sender: { type: Object, default: null },
  inbox: { type: Object, default: null },
  scheduledAt: { type: Number, default: 0 },
  deliveryReport: { type: Object, default: null },
  isExpanded: { type: Boolean, default: false },
});

const emit = defineEmits(['edit', 'viewDetails', 'toggle']);

const { t } = useI18n();

const STATUS_COMPLETED = 'completed';
const DELIVERY_STATUS_COMPLETED_WITH_ERRORS = 'completed_with_errors';

const hasDeliveryErrors = computed(
  () => props.deliveryReport?.status === DELIVERY_STATUS_COMPLETED_WITH_ERRORS
);

const statusBadgeClass = computed(() => {
  if (hasDeliveryErrors.value) return 'bg-n-ruby-3 text-n-ruby-11';
  if (props.isLiveChatType) {
    return props.isEnabled
      ? 'bg-n-teal-3 text-n-teal-11'
      : 'bg-n-alpha-2 text-n-slate-11';
  }
  if (props.status === STATUS_COMPLETED) return 'bg-n-teal-3 text-n-teal-11';
  return 'bg-n-amber-3 text-n-amber-11';
});

const campaignStatus = computed(() => {
  if (props.isLiveChatType) {
    return props.isEnabled
      ? t('CAMPAIGN.LIVE_CHAT.CARD.STATUS.ENABLED')
      : t('CAMPAIGN.LIVE_CHAT.CARD.STATUS.DISABLED');
  }
  if (hasDeliveryErrors.value) {
    return t('CAMPAIGN.SMS.CARD.STATUS.COMPLETED_WITH_ERRORS');
  }
  return props.status === STATUS_COMPLETED
    ? t('CAMPAIGN.SMS.CARD.STATUS.COMPLETED')
    : t('CAMPAIGN.SMS.CARD.STATUS.SCHEDULED');
});

const canViewDetails = computed(() => !props.isLiveChatType);

const inboxName = computed(() => props.inbox?.name || '');

const inboxIcon = computed(() => {
  if (!props.inbox) return '';
  const { medium, channel_type: type, additional_attributes } = props.inbox;
  return getInboxIconByType(type, medium, 'fill', additional_attributes);
});

const senderName = computed(
  () => props.sender?.name || t('CAMPAIGN.LIVE_CHAT.CARD.CAMPAIGN_DETAILS.BOT')
);

const hasDeliveryReport = computed(() => !!props.deliveryReport);

const formatDate = timestamp => {
  if (!timestamp) return '-';
  const date =
    typeof timestamp === 'number'
      ? fromUnixTime(timestamp)
      : new Date(timestamp);
  return format(date, 'LLL d, h:mm a');
};

const onClickExpand = () => emit('toggle');
const onClickViewDetails = () => emit('viewDetails');
</script>

<template>
  <div class="relative">
    <CardLayout :key="id" layout="row">
      <div class="flex items-center justify-between flex-1 min-w-0 gap-3">
        <div class="flex flex-col gap-0.5 flex-1 min-w-0">
          <div class="flex items-center gap-3">
            <span class="text-base font-medium text-n-slate-12 truncate">
              {{ title }}
            </span>
            <span
              class="text-xs font-medium inline-flex items-center shrink-0 h-5 px-2 py-0.5 rounded-md"
              :class="statusBadgeClass"
            >
              {{ campaignStatus }}
            </span>
          </div>
          <div class="flex flex-wrap items-center gap-x-3 gap-y-1 text-sm">
            <template v-if="isLiveChatType">
              <span class="text-n-slate-11">
                {{ t('CAMPAIGN.LIVE_CHAT.CARD.CAMPAIGN_DETAILS.SENT_BY') }}
              </span>
              <span class="font-medium text-n-slate-12">
                {{ senderName }}
              </span>
              <div class="w-px h-3 bg-n-slate-6" />
            </template>
            <div class="flex items-center gap-1.5">
              <Icon
                :icon="inboxIcon"
                class="flex-shrink-0 text-n-slate-11 size-3"
              />
              <span class="text-n-slate-11">{{ inboxName }}</span>
            </div>
            <template v-if="scheduledAt">
              <div class="w-px h-3 bg-n-slate-6" />
              <span class="text-n-slate-11">
                {{ formatDate(scheduledAt) }}
              </span>
            </template>
            <template v-if="canViewDetails">
              <div class="w-px h-3 bg-n-slate-6" />
              <Button
                :label="t('CAMPAIGN.CARD.VIEW_DETAILS')"
                variant="link"
                size="xs"
                @click.stop="onClickViewDetails"
              />
            </template>
          </div>
        </div>
        <div class="flex items-center gap-2 shrink-0">
          <Button
            v-if="isLiveChatType"
            variant="faded"
            size="sm"
            color="slate"
            icon="i-lucide-sliders-vertical"
            @click.stop="emit('edit')"
          />
          <Button
            v-if="canViewDetails"
            icon="i-lucide-chevron-down"
            variant="ghost"
            color="slate"
            size="xs"
            :class="{ 'rotate-180': isExpanded }"
            @click.stop="onClickExpand"
          />
        </div>
      </div>

      <template #after>
        <div
          class="transition-all duration-500 ease-in-out grid overflow-hidden"
          :class="
            isExpanded
              ? 'grid-rows-[1fr] opacity-100'
              : 'grid-rows-[0fr] opacity-0'
          "
        >
          <div class="overflow-hidden">
            <div
              v-if="hasDeliveryReport"
              class="flex items-center gap-6 px-6 py-4 border-t border-n-strong text-sm"
            >
              <div class="flex items-center gap-1.5">
                <span class="text-n-slate-11">
                  {{ t('CAMPAIGN.DELIVERY_REPORT.TOTAL') }}
                </span>
                <span class="font-semibold text-n-slate-12">
                  {{ deliveryReport.total }}
                </span>
              </div>
              <div class="flex items-center gap-1.5">
                <span class="text-n-teal-11">
                  {{ t('CAMPAIGN.DELIVERY_REPORT.SUCCEEDED') }}
                </span>
                <span class="font-semibold text-n-teal-11">
                  {{ deliveryReport.succeeded }}
                </span>
              </div>
              <div class="flex items-center gap-1.5">
                <span class="text-n-ruby-11">
                  {{ t('CAMPAIGN.DELIVERY_REPORT.FAILED') }}
                </span>
                <span class="font-semibold text-n-ruby-11">
                  {{ deliveryReport.failed }}
                </span>
              </div>
              <div
                v-if="deliveryReport.started_at"
                class="flex items-center gap-1.5 ml-auto"
              >
                <span class="text-n-slate-11">
                  {{ t('CAMPAIGN.DELIVERY_REPORT.STARTED_AT') }}
                </span>
                <span class="font-medium text-n-slate-12">
                  {{ formatDate(deliveryReport.started_at) }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </template>
    </CardLayout>
  </div>
</template>
