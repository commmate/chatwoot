<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { format, fromUnixTime } from 'date-fns';

import CampaignDetailLayout from 'dashboard/components-next/Campaigns/CampaignDetailLayout.vue';
import CampaignMessagesTable from 'dashboard/components-next/Campaigns/CampaignMessagesTable.vue';
import TemplatePreview from 'dashboard/components-next/Templates/TemplateBuilder/TemplatePreview.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ConfirmDeleteCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/ConfirmDeleteCampaignDialog.vue';

import { ref } from 'vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();

const confirmDeleteRef = ref(null);

const getCampaignById = useMapGetter('campaigns/getCampaignById');
const getLabelById = useMapGetter('labels/getLabelById');
const uiFlags = useMapGetter('campaigns/getUIFlags');
const isFetching = computed(() => uiFlags.value.isFetching);

const campaign = computed(() => getCampaignById.value(route.params.campaignId));

const ROUTE_TO_CHANNEL = {
  campaigns_email_detail: 'email',
  campaigns_whatsapp_detail: 'whatsapp',
  campaigns_sms_detail: 'sms',
};

const channelType = computed(() => ROUTE_TO_CHANNEL[route.name] || 'email');

const CHANNEL_LABELS = {
  email: 'CAMPAIGN.DETAIL_PAGE.BREADCRUMB.EMAIL',
  whatsapp: 'CAMPAIGN.DETAIL_PAGE.BREADCRUMB.WHATSAPP',
  sms: 'CAMPAIGN.DETAIL_PAGE.BREADCRUMB.SMS',
};

const channelLabel = computed(() =>
  t(CHANNEL_LABELS[channelType.value] || CHANNEL_LABELS.email)
);

const LIST_ROUTES = {
  email: 'campaigns_email_index',
  whatsapp: 'campaigns_whatsapp_index',
  sms: 'campaigns_sms_index',
};

const isWhatsApp = computed(() => channelType.value === 'whatsapp');
const isEmail = computed(() => channelType.value === 'email');

const campaignTitle = computed(() => {
  if (!campaign.value) return '';
  return (
    campaign.value.additional_attributes?.email_subject ||
    campaign.value.title ||
    ''
  );
});

const deliveryReport = computed(() => campaign.value?.delivery_report);
const hasDeliveryReport = computed(() => !!deliveryReport.value);
const hasErrors = computed(() => deliveryReport.value?.errors?.length > 0);

const statusConfig = computed(() => {
  if (!campaign.value) return null;

  const campaignStatus = campaign.value.campaign_status;
  const drStatus = deliveryReport.value?.status;

  if (drStatus === 'completed') {
    return {
      text: t('CAMPAIGN.DETAILS.STATUS_SUCCESS'),
      color: 'bg-n-teal-3 text-n-teal-11',
      icon: 'i-lucide-check-circle',
    };
  }
  if (drStatus === 'completed_with_errors') {
    return {
      text: t('CAMPAIGN.DETAILS.STATUS_WITH_ERRORS'),
      color: 'bg-n-ruby-3 text-n-ruby-11',
      icon: 'i-lucide-alert-circle',
    };
  }
  if (drStatus === 'running') {
    return {
      text: t('CAMPAIGN.DETAILS.STATUS_RUNNING'),
      color: 'bg-n-amber-3 text-n-amber-11',
      icon: 'i-lucide-loader',
    };
  }
  if (campaignStatus === 'completed') {
    return {
      text: t('CAMPAIGN.SMS.CARD.STATUS.COMPLETED'),
      color: 'bg-n-slate-3 text-n-slate-11',
      icon: 'i-lucide-check-circle',
    };
  }
  if (campaignStatus === 'sending') {
    return {
      text: t('CAMPAIGN.SMS.CARD.STATUS.SENDING'),
      color: 'bg-n-blue-3 text-n-blue-11',
      icon: 'i-lucide-loader',
    };
  }
  return {
    text: t('CAMPAIGN.SMS.CARD.STATUS.SCHEDULED'),
    color: 'bg-n-amber-3 text-n-amber-11',
    icon: 'i-lucide-clock',
  };
});

const isScheduled = computed(
  () =>
    !hasDeliveryReport.value && campaign.value?.campaign_status !== 'completed'
);

const campaignMessage = computed(() => campaign.value?.message || '');
const hasMessage = computed(() => campaignMessage.value.length > 0);

const senderName = computed(() => campaign.value?.sender?.name || '');

const createdAt = computed(() => campaign.value?.created_at);

const isSftpCampaign = computed(
  () => !!campaign.value?.additional_attributes?.sftp_source
);

const emailSubject = computed(
  () =>
    campaign.value?.additional_attributes?.email_subject ||
    campaign.value?.title ||
    ''
);

const replyToEmail = computed(() => {
  const attrs = campaign.value?.additional_attributes;
  if (!attrs) return null;
  if (attrs.use_inbox_reply_to) {
    return campaign.value?.inbox?.email || 'Inbox email';
  }
  return attrs.reply_to_email || null;
});

const recipientCount = computed(
  () => campaign.value?.additional_attributes?.recipient_count || 0
);

const hasAttachments = computed(
  () => !!campaign.value?.additional_attributes?.has_attachments
);

const attachmentCount = computed(
  () => campaign.value?.additional_attributes?.attachment_count || 0
);

const audienceLabels = computed(() => {
  if (!campaign.value?.audience) return [];
  return campaign.value.audience
    .filter(a => a.type === 'Label')
    .map(a => {
      const label = getLabelById.value(a.id);
      return {
        id: a.id,
        title: label?.title || `#${a.id}`,
        color: label?.color || '#6b7280',
      };
    });
});

const templateParams = computed(() => campaign.value?.template_params);
const templateName = computed(() => {
  const name = templateParams.value?.name;
  if (!name) return null;
  return name.replace(/_/g, ' ');
});

const hasTemplatePreview = computed(
  () => isWhatsApp.value && !!templateParams.value
);

const previewProps = computed(() => {
  const defaultProps = {
    headerFormat: null,
    headerText: '',
    headerTextExample: '',
    headerMediaUrl: '',
    headerMediaName: '',
    bodyText: campaign.value?.message || '',
    bodyExamples: [],
    footerText: '',
    buttons: [],
  };
  if (!campaign.value?.template_params) return defaultProps;

  const processedParams = templateParams.value?.processed_params || {};
  let headerFormat = null;
  let mediaUrl = '';
  let mediaName = '';

  if (processedParams.header?.media_url) {
    const url = processedParams.header.media_url;
    mediaUrl = url;
    mediaName = processedParams.header.media_name || '';
    if (url.match(/\.(jpg|jpeg|png|gif|webp)($|\?)/i)) {
      headerFormat = 'IMAGE';
    } else if (url.match(/\.(mp4|mov|avi)($|\?)/i)) {
      headerFormat = 'VIDEO';
    } else if (url.match(/\.(pdf|doc|docx|xls|xlsx)($|\?)/i)) {
      headerFormat = 'DOCUMENT';
    } else {
      headerFormat = 'IMAGE';
    }
  }

  return {
    ...defaultProps,
    headerFormat,
    headerMediaUrl: mediaUrl,
    headerMediaName: mediaName,
    bodyText: campaign.value?.message || '',
  };
});

const inboxChannelType = computed(() => {
  if (isWhatsApp.value) return 'Channel::Whatsapp';
  if (isEmail.value) return 'Channel::Email';
  return 'Channel::Sms';
});

const formatDate = timestamp => {
  if (!timestamp) return '-';
  const date =
    typeof timestamp === 'number'
      ? fromUnixTime(timestamp)
      : new Date(timestamp);
  return format(date, 'LLL d, h:mm a');
};

const goBack = () => {
  const listRoute = LIST_ROUTES[channelType.value] || 'campaigns_email_index';
  router.push({ name: listRoute });
};

const handleDelete = () => {
  confirmDeleteRef.value?.dialogRef?.open();
};

onMounted(() => {
  if (!campaign.value) {
    store.dispatch('campaigns/get');
  }
  store.dispatch('labels/get');
});
</script>

<template>
  <div
    class="flex flex-col justify-between flex-1 h-full m-0 overflow-auto bg-n-surface-1"
  >
    <div
      v-if="isFetching"
      class="flex items-center justify-center py-10 text-n-slate-11"
    >
      <Spinner />
    </div>

    <div
      v-else-if="!campaign"
      class="flex flex-col items-center justify-center py-20 gap-4"
    >
      <Icon icon="i-lucide-search-x" class="size-12 text-n-slate-9" />
      <span class="text-lg font-medium text-n-slate-11">
        {{ t('CAMPAIGN.DETAIL_PAGE.NOT_FOUND') }}
      </span>
      <span class="text-sm text-n-slate-10">
        {{ t('CAMPAIGN.DETAIL_PAGE.NOT_FOUND_DESCRIPTION') }}
      </span>
    </div>

    <CampaignDetailLayout
      v-else
      :campaign-title="campaignTitle"
      :channel-label="channelLabel"
      @go-back="goBack"
    >
      <div class="flex flex-col gap-6">
        <!-- Status Badge -->
        <div v-if="statusConfig" class="flex items-center gap-2">
          <span
            class="px-2.5 py-1 rounded-lg text-xs font-medium inline-flex items-center gap-1.5"
            :class="statusConfig.color"
          >
            <Icon :icon="statusConfig.icon" class="size-3.5" />
            {{ statusConfig.text }}
          </span>
        </div>

        <!-- Campaign Info -->
        <div class="flex flex-col gap-4">
          <div v-if="isEmail" class="flex flex-col gap-1">
            <span class="text-xs text-n-slate-11 uppercase tracking-wide">
              {{ t('CAMPAIGN.EMAIL.DETAILS.SUBJECT') }}
            </span>
            <span class="text-sm font-medium text-n-slate-12">
              {{ emailSubject }}
            </span>
          </div>

          <div v-if="isWhatsApp && templateName" class="flex flex-col gap-1">
            <span class="text-xs text-n-slate-11 uppercase tracking-wide">
              {{ t('CAMPAIGN.DETAILS.TEMPLATE') }}
            </span>
            <span class="text-sm font-medium text-n-slate-12 capitalize">
              {{ templateName }}
            </span>
          </div>

          <div class="grid grid-cols-2 sm:grid-cols-3 gap-4">
            <div v-if="campaign.inbox" class="flex flex-col gap-1">
              <span class="text-xs text-n-slate-11 uppercase tracking-wide">
                {{ t('CAMPAIGN.DETAILS.INBOX') }}
              </span>
              <span class="text-sm font-medium text-n-slate-12">
                {{ campaign.inbox.name }}
              </span>
            </div>

            <div v-if="channelType" class="flex flex-col gap-1">
              <span class="text-xs text-n-slate-11 uppercase tracking-wide">
                {{ t('CAMPAIGN.DETAILS.CHANNEL') }}
              </span>
              <span class="text-sm font-medium text-n-slate-12 capitalize">
                {{ channelType }}
              </span>
            </div>

            <div v-if="senderName" class="flex flex-col gap-1">
              <span class="text-xs text-n-slate-11 uppercase tracking-wide">
                {{ t('CAMPAIGN.DETAILS.SENDER') }}
              </span>
              <span class="text-sm font-medium text-n-slate-12">
                {{ senderName }}
              </span>
            </div>

            <div v-if="campaign.scheduled_at" class="flex flex-col gap-1">
              <span class="text-xs text-n-slate-11 uppercase tracking-wide">
                {{ t('CAMPAIGN.DETAILS.SCHEDULED_AT') }}
              </span>
              <span class="text-sm font-medium text-n-slate-12">
                {{ formatDate(campaign.scheduled_at) }}
              </span>
            </div>

            <div v-if="createdAt" class="flex flex-col gap-1">
              <span class="text-xs text-n-slate-11 uppercase tracking-wide">
                {{ t('CAMPAIGN.DETAILS.CREATED_AT') }}
              </span>
              <span class="text-sm font-medium text-n-slate-12">
                {{ formatDate(createdAt) }}
              </span>
            </div>

            <div v-if="replyToEmail" class="flex flex-col gap-1">
              <span class="text-xs text-n-slate-11 uppercase tracking-wide">
                {{ t('CAMPAIGN.DETAILS.REPLY_TO') }}
              </span>
              <span class="text-sm font-medium text-n-slate-12">
                {{ replyToEmail }}
              </span>
            </div>

            <div
              v-if="isWhatsApp && templateParams?.language"
              class="flex flex-col gap-1"
            >
              <span class="text-xs text-n-slate-11 uppercase tracking-wide">
                {{ t('CAMPAIGN.DETAILS.LANGUAGE') }}
              </span>
              <span class="text-sm font-medium text-n-slate-12">
                {{ templateParams.language }}
              </span>
            </div>

            <div
              v-if="isSftpCampaign && recipientCount"
              class="flex flex-col gap-1"
            >
              <span class="text-xs text-n-slate-11 uppercase tracking-wide">
                {{ t('CAMPAIGN.DELIVERY_REPORT.TOTAL') }}
              </span>
              <span class="text-sm font-medium text-n-slate-12">
                {{
                  t('CAMPAIGN.EMAIL.DETAILS.RECIPIENT_COUNT', {
                    count: recipientCount,
                  })
                }}
              </span>
            </div>
          </div>
        </div>

        <!-- Audience Labels -->
        <div v-if="audienceLabels.length" class="flex flex-col gap-2">
          <span class="text-xs text-n-slate-11 uppercase tracking-wide">
            {{ t('CAMPAIGN.DETAILS.AUDIENCE') }}
          </span>
          <div class="flex flex-wrap gap-2">
            <span
              v-for="label in audienceLabels"
              :key="label.id"
              class="inline-flex items-center gap-1.5 text-sm px-3 py-1 rounded-lg bg-n-alpha-2 text-n-slate-12 border border-n-weak"
            >
              <span
                class="size-2 rounded-full"
                :style="{ backgroundColor: label.color }"
              />
              {{ label.title }}
            </span>
          </div>
        </div>

        <!-- Message Content (for non-template campaigns) -->
        <div
          v-if="hasMessage && !hasTemplatePreview"
          class="flex flex-col gap-2 pt-4 border-t border-n-weak"
        >
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('CAMPAIGN.DETAIL_PAGE.MESSAGE_CONTENT') }}
          </span>
          <div
            v-if="isEmail"
            class="p-4 rounded-xl border border-n-weak bg-white text-sm text-n-slate-12 max-h-60 overflow-y-auto prose prose-sm"
            v-html="campaignMessage"
          />
          <div
            v-else
            class="p-4 rounded-xl border border-n-weak bg-n-alpha-1 text-sm text-n-slate-12 whitespace-pre-wrap"
          >
            {{ campaignMessage }}
          </div>
          <div
            v-if="hasAttachments"
            class="flex items-center gap-2 px-3 py-2 rounded-lg bg-n-alpha-1 border border-n-weak"
          >
            <Icon
              icon="i-lucide-paperclip"
              class="size-4 text-n-slate-11 shrink-0"
            />
            <span class="text-sm text-n-slate-11">
              {{
                t('CAMPAIGN.EMAIL.DETAILS.ATTACHMENT_COUNT', {
                  count: attachmentCount,
                })
              }}
            </span>
          </div>
        </div>

        <!-- Scheduled Info Banner -->
        <div
          v-if="isScheduled"
          class="flex items-center gap-3 p-4 rounded-xl bg-n-amber-2 border border-n-amber-6"
        >
          <Icon icon="i-lucide-clock" class="size-5 text-n-amber-11 shrink-0" />
          <span class="text-sm text-n-amber-11">
            {{ t('CAMPAIGN.DETAIL_PAGE.AWAITING_SEND') }}
          </span>
        </div>

        <!-- Delivery Report -->
        <div
          v-if="hasDeliveryReport"
          class="flex flex-col gap-4 pt-4 border-t border-n-weak"
        >
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('CAMPAIGN.DELIVERY_REPORT.TITLE') }}
          </span>

          <div class="grid grid-cols-3 gap-3">
            <div
              class="flex flex-col items-center gap-1 p-3 rounded-xl bg-n-alpha-2 border border-n-weak"
            >
              <span class="text-2xl font-bold text-n-slate-12">
                {{ deliveryReport.total }}
              </span>
              <span class="text-xs text-n-slate-11 uppercase tracking-wide">
                {{ t('CAMPAIGN.DELIVERY_REPORT.TOTAL') }}
              </span>
            </div>
            <div
              class="flex flex-col items-center gap-1 p-3 rounded-xl bg-n-teal-2 border border-n-teal-6"
            >
              <span class="text-2xl font-bold text-n-teal-11">
                {{ deliveryReport.succeeded }}
              </span>
              <span class="text-xs text-n-teal-11 uppercase tracking-wide">
                {{ t('CAMPAIGN.DELIVERY_REPORT.SUCCEEDED') }}
              </span>
            </div>
            <div
              class="flex flex-col items-center gap-1 p-3 rounded-xl bg-n-ruby-2 border border-n-ruby-6"
            >
              <span class="text-2xl font-bold text-n-ruby-11">
                {{ deliveryReport.failed }}
              </span>
              <span class="text-xs text-n-ruby-11 uppercase tracking-wide">
                {{ t('CAMPAIGN.DELIVERY_REPORT.FAILED') }}
              </span>
            </div>
          </div>

          <div class="grid grid-cols-2 gap-4 text-sm">
            <div class="flex flex-col gap-1">
              <span class="text-xs text-n-slate-11 uppercase tracking-wide">
                {{ t('CAMPAIGN.DELIVERY_REPORT.STARTED_AT') }}
              </span>
              <span class="text-n-slate-12 font-medium">
                {{ formatDate(deliveryReport.started_at) }}
              </span>
            </div>
            <div class="flex flex-col gap-1">
              <span class="text-xs text-n-slate-11 uppercase tracking-wide">
                {{ t('CAMPAIGN.DELIVERY_REPORT.COMPLETED_AT') }}
              </span>
              <span class="text-n-slate-12 font-medium">
                {{ formatDate(deliveryReport.completed_at) }}
              </span>
            </div>
          </div>

          <!-- Errors -->
          <div v-if="hasErrors" class="flex flex-col gap-2">
            <div class="flex items-center gap-2">
              <Icon
                icon="i-lucide-alert-triangle"
                class="size-4 text-n-ruby-11"
              />
              <span class="text-sm font-medium text-n-ruby-11">
                {{ t('CAMPAIGN.DELIVERY_REPORT.ERRORS_TITLE') }}
              </span>
            </div>
            <div class="flex flex-col gap-1.5 max-h-40 overflow-y-auto">
              <div
                v-for="(error, index) in deliveryReport.errors"
                :key="index"
                class="flex items-center gap-2 px-3 py-2 rounded-lg bg-n-ruby-2 border border-n-ruby-6"
              >
                <span
                  v-if="error.code"
                  class="text-[10px] font-mono px-1.5 py-0.5 rounded bg-n-ruby-4 text-n-ruby-11 shrink-0"
                >
                  {{ error.code }}
                </span>
                <div class="flex-1 min-w-0">
                  <span class="text-xs text-n-slate-12 font-medium">
                    {{ error.message }}
                  </span>
                  <span
                    v-if="error.details"
                    class="text-xs text-n-slate-11 ml-1"
                  >
                    {{
                      t('CAMPAIGN.DELIVERY_REPORT.ERROR_DETAILS_SEPARATOR', {
                        details: error.details,
                      })
                    }}
                  </span>
                </div>
                <span
                  class="text-[10px] text-n-ruby-11 bg-n-ruby-3 px-1.5 py-0.5 rounded shrink-0"
                >
                  {{
                    t('CAMPAIGN.DELIVERY_REPORT.ERROR_COUNT', {
                      count: error.count,
                    })
                  }}
                </span>
              </div>
            </div>
          </div>
        </div>

        <!-- Recipients Table -->
        <div v-if="hasDeliveryReport" class="pt-4 border-t border-n-weak">
          <CampaignMessagesTable
            :campaign-id="campaign.id"
            :channel-type="inboxChannelType"
          />
        </div>

        <!-- Delete Campaign -->
        <div
          class="flex flex-col items-start w-full gap-4 pt-6 mt-6 border-t border-n-strong"
        >
          <div class="flex flex-col gap-2">
            <h6 class="text-base font-medium text-n-slate-12">
              {{ t('CAMPAIGN.DETAIL_PAGE.DELETE_TITLE') }}
            </h6>
            <span class="text-sm text-n-slate-11">
              {{ t('CAMPAIGN.DETAIL_PAGE.DELETE_DESCRIPTION') }}
            </span>
          </div>
          <Button
            :label="t('CAMPAIGN.DETAIL_PAGE.DELETE_TITLE')"
            color="ruby"
            @click="handleDelete"
          />
        </div>
      </div>

      <!-- Sidebar: Template Preview (WhatsApp only) -->
      <template v-if="hasTemplatePreview" #sidebar>
        <div class="sticky top-6 px-4">
          <div class="flex items-center gap-2 mb-4">
            <Icon icon="i-lucide-smartphone" class="size-4 text-n-slate-11" />
            <span
              class="text-sm font-semibold text-n-slate-12 uppercase tracking-wide"
            >
              {{ t('CAMPAIGN.DETAIL_PAGE.PREVIEW') }}
            </span>
          </div>
          <TemplatePreview
            :header-format="previewProps.headerFormat"
            :header-text="previewProps.headerText"
            :header-text-example="previewProps.headerTextExample"
            :header-media-url="previewProps.headerMediaUrl"
            :header-media-name="previewProps.headerMediaName"
            :body-text="previewProps.bodyText"
            :body-examples="previewProps.bodyExamples"
            :footer-text="previewProps.footerText"
            :buttons="previewProps.buttons"
          />
        </div>
      </template>
    </CampaignDetailLayout>

    <ConfirmDeleteCampaignDialog
      ref="confirmDeleteRef"
      :selected-campaign="campaign"
    />
  </div>
</template>
