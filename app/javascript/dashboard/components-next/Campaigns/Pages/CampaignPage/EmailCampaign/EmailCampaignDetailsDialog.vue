<script setup>
import { computed, ref, watch, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import { format, fromUnixTime } from 'date-fns';
import { useMapGetter } from 'dashboard/composables/store';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  isOpen: {
    type: Boolean,
    default: false,
  },
  campaign: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();

const dialogRef = ref(null);
const getLabelById = useMapGetter('labels/getLabelById');

watch(
  () => props.isOpen,
  async newVal => {
    if (newVal) {
      await nextTick();
      dialogRef.value?.open();
    } else {
      dialogRef.value?.close();
    }
  }
);

// SFTP campaign detection
const isSftpCampaign = computed(
  () => !!props.campaign?.additional_attributes?.sftp_source
);

// Email-specific computed properties
const emailSubject = computed(
  () =>
    props.campaign?.additional_attributes?.email_subject ||
    props.campaign?.title ||
    ''
);

const emailHtmlBody = computed(() => props.campaign?.message || '');

const recipientCount = computed(
  () => props.campaign?.additional_attributes?.recipient_count || 0
);

const hasAttachments = computed(
  () => !!props.campaign?.additional_attributes?.has_attachments
);

const attachmentCount = computed(
  () => props.campaign?.additional_attributes?.attachment_count || 0
);

const replyToEmail = computed(() => {
  const attrs = props.campaign?.additional_attributes;
  if (!attrs) return null;
  if (attrs.use_inbox_reply_to) {
    return props.campaign?.inbox?.email || 'Inbox email';
  }
  return attrs.reply_to_email || null;
});

// Delivery Report
const deliveryReport = computed(() => props.campaign?.delivery_report);
const hasDeliveryReport = computed(() => !!deliveryReport.value);
const hasErrors = computed(() => deliveryReport.value?.errors?.length > 0);

// Status
const statusConfig = computed(() => {
  if (!hasDeliveryReport.value) {
    const isCompleted = props.campaign?.campaign_status === 'completed';
    return {
      text: isCompleted
        ? t('CAMPAIGN.SMS.CARD.STATUS.COMPLETED')
        : t('CAMPAIGN.SMS.CARD.STATUS.SCHEDULED'),
      color: isCompleted
        ? 'bg-n-slate-3 text-n-slate-11'
        : 'bg-n-teal-3 text-n-teal-11',
      icon: isCompleted ? 'i-lucide-check-circle' : 'i-lucide-clock',
    };
  }

  const status = deliveryReport.value?.status;
  if (status === 'completed') {
    return {
      text: t('CAMPAIGN.DETAILS.STATUS_SUCCESS'),
      color: 'bg-n-teal-3 text-n-teal-11',
      icon: 'i-lucide-check-circle',
    };
  }
  if (status === 'completed_with_errors') {
    return {
      text: t('CAMPAIGN.DETAILS.STATUS_WITH_ERRORS'),
      color: 'bg-n-ruby-3 text-n-ruby-11',
      icon: 'i-lucide-alert-circle',
    };
  }
  if (status === 'running') {
    return {
      text: t('CAMPAIGN.DETAILS.STATUS_RUNNING'),
      color: 'bg-n-amber-3 text-n-amber-11',
      icon: 'i-lucide-loader',
    };
  }
  return {
    text: status || t('CAMPAIGN.SMS.CARD.STATUS.SCHEDULED'),
    color: 'bg-n-slate-3 text-n-slate-11',
    icon: 'i-lucide-clock',
  };
});

// Audience Labels with names
const audienceLabels = computed(() => {
  if (!props.campaign?.audience) return [];
  return props.campaign.audience
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

const formatDate = timestamp => {
  if (!timestamp) return '-';
  const date =
    typeof timestamp === 'number'
      ? fromUnixTime(timestamp)
      : new Date(timestamp);
  return format(date, 'LLL d, h:mm a');
};

const handleClose = () => emit('close');
</script>

<template>
  <Dialog
    ref="dialogRef"
    :show-cancel-button="false"
    :show-confirm-button="false"
    width="5xl"
    @close="handleClose"
  >
    <div class="flex flex-col -mx-6 -my-6 max-h-[85vh]">
      <!-- Header -->
      <div class="flex-shrink-0 px-6 py-4 border-b border-n-weak">
        <div class="flex items-start justify-between gap-4">
          <div class="flex flex-col gap-1 min-w-0 flex-1">
            <h3 class="text-lg font-semibold text-n-slate-12 truncate">
              {{ campaign?.title }}
            </h3>
            <div class="flex items-center gap-2 text-sm text-n-slate-11">
              <Icon :icon="statusConfig.icon" class="size-4" />
              <span
                class="px-2 py-0.5 rounded-md text-xs font-medium"
                :class="statusConfig.color"
              >
                {{ statusConfig.text }}
              </span>
            </div>
          </div>
          <button
            class="p-1.5 rounded-lg hover:bg-n-alpha-2 transition-colors"
            @click="handleClose"
          >
            <Icon icon="i-lucide-x" class="size-5 text-n-slate-11" />
          </button>
        </div>
      </div>

      <!-- Content: Two columns -->
      <div class="flex-1 flex gap-6 p-6 overflow-hidden min-h-0">
        <!-- Left Panel: Campaign Info & Delivery Report -->
        <div class="flex-1 min-w-0 overflow-y-auto pr-4 space-y-5">
          <!-- Info Grid -->
          <div class="grid grid-cols-2 gap-4">
            <!-- Email Subject -->
            <div
              class="flex flex-col gap-1.5 p-3 rounded-xl bg-n-alpha-1 col-span-2"
            >
              <div class="flex items-center gap-2">
                <Icon icon="i-lucide-mail" class="size-4 text-n-slate-10" />
                <span
                  class="text-xs font-medium text-n-slate-11 uppercase tracking-wide"
                >
                  {{ t('CAMPAIGN.EMAIL.DETAILS.SUBJECT') }}
                </span>
              </div>
              <span class="text-sm font-medium text-n-slate-12">
                {{ emailSubject }}
              </span>
            </div>

            <!-- Inbox -->
            <div
              v-if="campaign?.inbox"
              class="flex flex-col gap-1.5 p-3 rounded-xl bg-n-alpha-1"
            >
              <div class="flex items-center gap-2">
                <Icon icon="i-lucide-inbox" class="size-4 text-n-slate-10" />
                <span
                  class="text-xs font-medium text-n-slate-11 uppercase tracking-wide"
                >
                  {{ t('CAMPAIGN.DETAILS.INBOX') }}
                </span>
              </div>
              <span class="text-sm font-medium text-n-slate-12">
                {{ campaign.inbox.name }}
              </span>
            </div>

            <!-- Reply-To -->
            <div
              v-if="replyToEmail"
              class="flex flex-col gap-1.5 p-3 rounded-xl bg-n-alpha-1"
            >
              <div class="flex items-center gap-2">
                <Icon icon="i-lucide-reply" class="size-4 text-n-slate-10" />
                <span
                  class="text-xs font-medium text-n-slate-11 uppercase tracking-wide"
                >
                  {{ t('CAMPAIGN.EMAIL.DETAILS.REPLY_TO') }}
                </span>
              </div>
              <span class="text-sm font-medium text-n-slate-12">
                {{ replyToEmail }}
              </span>
            </div>

            <!-- Scheduled At -->
            <div
              v-if="campaign?.scheduled_at"
              class="flex flex-col gap-1.5 p-3 rounded-xl bg-n-alpha-1"
            >
              <div class="flex items-center gap-2">
                <Icon icon="i-lucide-calendar" class="size-4 text-n-slate-10" />
                <span
                  class="text-xs font-medium text-n-slate-11 uppercase tracking-wide"
                >
                  {{ t('CAMPAIGN.DETAILS.SCHEDULED_AT') }}
                </span>
              </div>
              <span class="text-sm font-medium text-n-slate-12">
                {{ formatDate(campaign.scheduled_at) }}
              </span>
            </div>
          </div>

          <!-- Audience Labels -->
          <div v-if="audienceLabels.length" class="flex flex-col gap-2">
            <div class="flex items-center gap-2">
              <Icon icon="i-lucide-users" class="size-4 text-n-slate-11" />
              <span
                class="text-xs font-medium text-n-slate-11 uppercase tracking-wide"
              >
                {{ t('CAMPAIGN.DETAILS.AUDIENCE') }}
              </span>
            </div>
            <div class="flex flex-wrap gap-2">
              <span
                v-for="label in audienceLabels"
                :key="label.id"
                class="inline-flex items-center gap-1.5 text-sm px-3 py-1.5 rounded-lg bg-n-alpha-2 text-n-slate-12 border border-n-weak"
              >
                <span
                  class="size-2.5 rounded-full"
                  :style="{ backgroundColor: label.color }"
                />
                {{ label.title }}
              </span>
            </div>
          </div>

          <!-- Delivery Report Section -->
          <div
            v-if="hasDeliveryReport"
            class="flex flex-col gap-4 pt-4 border-t border-n-weak"
          >
            <div class="flex items-center gap-2">
              <Icon
                icon="i-lucide-bar-chart-2"
                class="size-4 text-n-slate-11"
              />
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('CAMPAIGN.DELIVERY_REPORT.TITLE') }}
              </span>
            </div>

            <!-- Stats Cards -->
            <div class="grid grid-cols-3 gap-3">
              <div
                class="flex flex-col items-center gap-1 p-4 rounded-xl bg-n-alpha-2 border border-n-weak"
              >
                <span class="text-3xl font-bold text-n-slate-12">
                  {{ deliveryReport.total }}
                </span>
                <span class="text-xs text-n-slate-11 uppercase tracking-wide">
                  {{ t('CAMPAIGN.DELIVERY_REPORT.TOTAL') }}
                </span>
              </div>
              <div
                class="flex flex-col items-center gap-1 p-4 rounded-xl bg-n-teal-2 border border-n-teal-6"
              >
                <span class="text-3xl font-bold text-n-teal-11">
                  {{ deliveryReport.succeeded }}
                </span>
                <span class="text-xs text-n-teal-11 uppercase tracking-wide">
                  {{ t('CAMPAIGN.DELIVERY_REPORT.SUCCEEDED') }}
                </span>
              </div>
              <div
                class="flex flex-col items-center gap-1 p-4 rounded-xl bg-n-ruby-2 border border-n-ruby-6"
              >
                <span class="text-3xl font-bold text-n-ruby-11">
                  {{ deliveryReport.failed }}
                </span>
                <span class="text-xs text-n-ruby-11 uppercase tracking-wide">
                  {{ t('CAMPAIGN.DELIVERY_REPORT.FAILED') }}
                </span>
              </div>
            </div>

            <!-- Timestamps -->
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

            <!-- Errors Section -->
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
                        $t('CAMPAIGN.DELIVERY_REPORT.ERROR_DETAILS_SEPARATOR', {
                          details: error.details,
                        })
                      }}
                    </span>
                  </div>
                  <span
                    class="text-[10px] text-n-ruby-11 bg-n-ruby-3 px-1.5 py-0.5 rounded shrink-0"
                  >
                    {{
                      $t('CAMPAIGN.DELIVERY_REPORT.ERROR_COUNT', {
                        count: error.count,
                      })
                    }}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Right Panel: Email Preview -->
        <div class="w-[400px] flex-shrink-0 flex flex-col overflow-hidden">
          <div class="flex items-center gap-2 mb-4">
            <Icon icon="i-lucide-eye" class="size-4 text-n-slate-11" />
            <span
              class="text-sm font-semibold text-n-slate-12 uppercase tracking-wide"
            >
              {{ t('CAMPAIGN.EMAIL.CREATE_DIALOG.PREVIEW_TITLE') }}
            </span>
            <span
              v-if="isSftpCampaign"
              class="text-[10px] font-medium px-2 py-0.5 rounded-full bg-n-amber-3 text-n-amber-11 uppercase tracking-wide"
            >
              {{ t('CAMPAIGN.EMAIL.DETAILS.SFTP_FIRST_EMAIL') }}
            </span>
          </div>

          <!-- Email Preview Container -->
          <div
            class="flex-1 overflow-hidden border rounded-xl border-n-weak bg-n-solid-1"
          >
            <!-- Email Header Preview -->
            <div class="px-4 py-3 border-b border-n-weak bg-n-solid-2">
              <div class="flex items-center gap-2 mb-2">
                <span class="text-xs font-medium text-n-slate-11">
                  {{ t('CAMPAIGN.EMAIL.DETAILS.SUBJECT_LABEL') }}
                </span>
                <span class="text-sm text-n-slate-12">
                  {{ emailSubject || 'No subject' }}
                </span>
              </div>
              <div v-if="replyToEmail" class="flex items-center gap-2 mb-2">
                <span class="text-xs font-medium text-n-slate-11">
                  {{ t('CAMPAIGN.EMAIL.DETAILS.REPLY_TO_LABEL') }}
                </span>
                <span class="text-xs text-n-slate-10">
                  {{ replyToEmail }}
                </span>
              </div>
              <div
                v-if="isSftpCampaign && recipientCount"
                class="flex items-center gap-2 mb-2"
              >
                <Icon
                  icon="i-lucide-users"
                  class="size-3.5 text-n-slate-10 shrink-0"
                />
                <span class="text-xs text-n-slate-11">
                  {{
                    t('CAMPAIGN.EMAIL.DETAILS.RECIPIENT_COUNT', {
                      count: recipientCount,
                    })
                  }}
                </span>
              </div>
              <div
                v-if="isSftpCampaign && hasAttachments"
                class="flex items-center gap-2"
              >
                <Icon
                  icon="i-lucide-paperclip"
                  class="size-3.5 text-n-slate-10"
                />
                <span class="text-xs text-n-slate-11">
                  {{
                    t('CAMPAIGN.EMAIL.DETAILS.ATTACHMENT_COUNT', {
                      count: attachmentCount,
                    })
                  }}
                </span>
              </div>
            </div>

            <!-- Email Body Preview -->
            <div class="h-full overflow-y-auto">
              <iframe
                :srcdoc="
                  emailHtmlBody ||
                  '<p style=\'color: #888; text-align: center; padding: 40px;\'>No content</p>'
                "
                class="w-full h-full min-h-[400px] border-0"
                sandbox="allow-same-origin"
                :title="t('CAMPAIGN.EMAIL.DETAILS.EMAIL_PREVIEW')"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div
        class="flex-shrink-0 flex justify-end gap-3 px-6 py-4 border-t border-n-weak"
      >
        <Button
          variant="faded"
          color="slate"
          :label="t('CAMPAIGN.DETAILS.CLOSE')"
          @click="handleClose"
        />
      </div>
    </div>
  </Dialog>
</template>
