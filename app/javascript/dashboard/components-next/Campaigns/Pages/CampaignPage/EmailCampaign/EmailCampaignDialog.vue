<script setup>
import { ref, computed, reactive, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, email } from '@vuelidate/validators';
import { useStore } from 'dashboard/composables/store';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert, useTrack } from 'dashboard/composables';
import { CAMPAIGN_TYPES } from 'shared/constants/campaign.js';
import { CAMPAIGNS_EVENTS } from 'dashboard/helper/AnalyticsHelper/events.js';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';

const emit = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();

// Store getters
const uiFlags = useMapGetter('campaigns/getUIFlags');
const campaignLabels = useMapGetter('labels/getCampaignLabels');
const inboxes = useMapGetter('inboxes/getResendInboxes');

// Dialog ref
const dialogRef = ref(null);

// Reply-to options: 'imap', 'resend', 'custom'
const REPLY_TO_OPTIONS = {
  IMAP: 'imap',
  RESEND: 'resend',
  CUSTOM: 'custom',
};

// Form state
const formState = reactive({
  title: '',
  subject: '',
  message: '',
  replyToOption: REPLY_TO_OPTIONS.RESEND, // Default to resend, will update when inbox selected
  replyToEmail: '',
  inboxId: null,
  scheduledAt: null,
  selectedAudience: [],
});

// Validation rules - replyToEmail optional but must be valid email if provided
const optionalEmail = value => !value || email.$validator(value);

const rules = {
  title: { required, minLength: minLength(1) },
  subject: { required, minLength: minLength(1) },
  message: { required, minLength: minLength(1) },
  replyToEmail: { optionalEmail },
  inboxId: { required },
  scheduledAt: { required },
  selectedAudience: { required },
};

const v$ = useVuelidate(rules, formState);

// Computed
const isCreating = computed(() => uiFlags.value.isCreating);

const currentDateTime = computed(() => {
  const now = new Date();
  const localTime = new Date(now.getTime() - now.getTimezoneOffset() * 60000);
  return localTime.toISOString().slice(0, 16);
});

const audienceOptions = computed(
  () =>
    campaignLabels.value?.map(label => ({
      value: label.id,
      label: label.title,
    })) ?? []
);

const inboxOptions = computed(
  () =>
    inboxes.value?.map(inbox => ({
      value: inbox.id,
      label: inbox.name,
    })) ?? []
);

// Get selected inbox's email for display
const selectedInbox = computed(() =>
  inboxes.value?.find(inbox => inbox.id === formState.inboxId)
);

// Check if IMAP is enabled for the selected inbox
const hasImapEnabled = computed(
  () => selectedInbox.value?.imap_enabled && selectedInbox.value?.imap_login
);

// Get IMAP email address
const imapEmail = computed(() => selectedInbox.value?.imap_login || '');

// Get Resend email address (from provider_config or channel email)
const resendEmail = computed(
  () =>
    selectedInbox.value?.provider_config?.from_email ||
    selectedInbox.value?.email ||
    ''
);

// Get the currently selected reply-to email based on option
const selectedReplyToEmail = computed(() => {
  if (!selectedInbox.value) return 'Select an inbox first';

  switch (formState.replyToOption) {
    case REPLY_TO_OPTIONS.IMAP:
      return imapEmail.value || 'IMAP not configured';
    case REPLY_TO_OPTIONS.RESEND:
      return resendEmail.value || 'Resend email not configured';
    case REPLY_TO_OPTIONS.CUSTOM:
      return formState.replyToEmail || 'Enter a custom email';
    default:
      return resendEmail.value;
  }
});

// Watch for inbox changes to set the default reply-to option
watch(
  () => formState.inboxId,
  () => {
    if (hasImapEnabled.value) {
      formState.replyToOption = REPLY_TO_OPTIONS.IMAP;
    } else {
      formState.replyToOption = REPLY_TO_OPTIONS.RESEND;
    }
  }
);

// Form errors
const formErrors = computed(() => ({
  title: v$.value.title.$error
    ? t('CAMPAIGN.EMAIL.CREATE.FORM.TITLE.ERROR')
    : '',
  subject: v$.value.subject.$error
    ? t('CAMPAIGN.EMAIL.CREATE.FORM.SUBJECT.ERROR')
    : '',
  message: v$.value.message.$error
    ? t('CAMPAIGN.EMAIL.CREATE.FORM.MESSAGE.ERROR')
    : '',
  replyToEmail: v$.value.replyToEmail.$error
    ? t('CAMPAIGN.EMAIL.CREATE.FORM.REPLY_TO.ERROR')
    : '',
  inbox: v$.value.inboxId.$error
    ? t('CAMPAIGN.EMAIL.CREATE.FORM.INBOX.ERROR')
    : '',
  scheduledAt: v$.value.scheduledAt.$error
    ? t('CAMPAIGN.EMAIL.CREATE.FORM.SCHEDULED_AT.ERROR')
    : '',
  audience: v$.value.selectedAudience.$error
    ? t('CAMPAIGN.EMAIL.CREATE.FORM.AUDIENCE.ERROR')
    : '',
}));

const isSubmitDisabled = computed(() => v$.value.$invalid);

// Computed for HTML preview
const previewHtml = computed(() => {
  return (
    formState.message ||
    '<p style="color: #888; text-align: center; padding: 40px;">Enter HTML content to see preview</p>'
  );
});

// Methods
const getReplyToEmailForPayload = () => {
  switch (formState.replyToOption) {
    case REPLY_TO_OPTIONS.IMAP:
      return imapEmail.value;
    case REPLY_TO_OPTIONS.RESEND:
      return resendEmail.value;
    case REPLY_TO_OPTIONS.CUSTOM:
      return formState.replyToEmail;
    default:
      return resendEmail.value;
  }
};

const prepareCampaignPayload = () => ({
  title: formState.title,
  message: formState.message,
  inbox_id: formState.inboxId,
  scheduled_at: formState.scheduledAt
    ? new Date(formState.scheduledAt).toISOString()
    : null,
  audience: formState.selectedAudience?.map(id => ({
    id,
    type: 'Label',
  })),
  additional_attributes: {
    email_subject: formState.subject,
    reply_to_option: formState.replyToOption,
    reply_to_email: getReplyToEmailForPayload(),
  },
});

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

  try {
    const payload = prepareCampaignPayload();
    await store.dispatch('campaigns/create', payload);

    useTrack(CAMPAIGNS_EVENTS.CREATE_CAMPAIGN, {
      type: CAMPAIGN_TYPES.ONE_OFF,
    });

    useAlert(t('CAMPAIGN.EMAIL.CREATE.SUCCESS'));
    dialogRef.value?.close();
  } catch (error) {
    const errorMessage =
      error?.response?.message || t('CAMPAIGN.EMAIL.CREATE.ERROR');
    useAlert(errorMessage);
  }
};

// Called when Dialog emits 'close'
const onDialogClose = () => {
  // Reset form state
  formState.title = '';
  formState.subject = '';
  formState.message = '';
  formState.replyToOption = REPLY_TO_OPTIONS.RESEND;
  formState.replyToEmail = '';
  formState.inboxId = null;
  formState.scheduledAt = null;
  formState.selectedAudience = [];
  v$.value.$reset();
  emit('close');
};

const handleCancel = () => {
  dialogRef.value?.close();
};

const openDialog = () => {
  dialogRef.value?.open();
};

defineExpose({ openDialog });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="5xl"
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="onDialogClose"
  >
    <div class="flex flex-col -mx-6 -my-6 max-h-[85vh]">
      <!-- Header -->
      <div class="flex-shrink-0 px-6 py-4 border-b border-n-weak">
        <h2 class="text-lg font-medium text-n-slate-12">
          {{ t('CAMPAIGN.EMAIL.CREATE_DIALOG.TITLE') }}
        </h2>
        <p class="mt-1 text-sm text-n-slate-11">
          {{ t('CAMPAIGN.EMAIL.CREATE_DIALOG.SUBTITLE') }}
        </p>
      </div>

      <!-- Content -->
      <div class="flex flex-1 min-h-0 gap-6 p-6 overflow-hidden">
        <!-- Form Panel -->
        <div class="flex-1 min-w-0 pr-4 space-y-6 overflow-y-auto">
          <!-- Basic Info Section -->
          <section
            class="p-5 shadow bg-n-solid-2 rounded-2xl outline-1 outline outline-n-container"
          >
            <div class="flex items-center gap-2 mb-4">
              <i class="text-lg i-lucide-settings-2 text-n-slate-11" />
              <h3
                class="text-sm font-semibold tracking-wide uppercase text-n-slate-12"
              >
                {{ t('CAMPAIGN.EMAIL.CREATE_DIALOG.SECTIONS.BASIC_INFO') }}
              </h3>
            </div>

            <div class="space-y-4">
              <!-- Campaign Title -->
              <Input
                v-model="formState.title"
                :label="t('CAMPAIGN.EMAIL.CREATE.FORM.TITLE.LABEL')"
                :placeholder="t('CAMPAIGN.EMAIL.CREATE.FORM.TITLE.PLACEHOLDER')"
                :message="formErrors.title"
                :message-type="formErrors.title ? 'error' : 'info'"
                required
              />

              <!-- Email Subject -->
              <Input
                v-model="formState.subject"
                :label="t('CAMPAIGN.EMAIL.CREATE.FORM.SUBJECT.LABEL')"
                :placeholder="
                  t('CAMPAIGN.EMAIL.CREATE.FORM.SUBJECT.PLACEHOLDER')
                "
                :message="formErrors.subject"
                :message-type="formErrors.subject ? 'error' : 'info'"
                required
              />

              <!-- Inbox Selection -->
              <div class="flex flex-col gap-1">
                <label
                  for="inbox"
                  class="mb-0.5 text-sm font-medium text-n-slate-12"
                >
                  {{ t('CAMPAIGN.EMAIL.CREATE.FORM.INBOX.LABEL') }}
                  <span class="text-red-500 ml-0.5">*</span>
                </label>
                <ComboBox
                  id="inbox"
                  v-model="formState.inboxId"
                  :options="inboxOptions"
                  :has-error="!!formErrors.inbox"
                  :placeholder="
                    t('CAMPAIGN.EMAIL.CREATE.FORM.INBOX.PLACEHOLDER')
                  "
                  :message="formErrors.inbox"
                />
              </div>

              <!-- Reply-To Email Options -->
              <div class="flex flex-col gap-2">
                <label class="mb-0.5 text-sm font-medium text-n-slate-12">
                  {{ t('CAMPAIGN.EMAIL.CREATE.FORM.REPLY_TO.TITLE') }}
                </label>
                <p class="text-xs text-n-slate-11 mb-2">
                  {{ t('CAMPAIGN.EMAIL.CREATE.FORM.REPLY_TO.DESCRIPTION') }}
                </p>

                <div
                  class="flex flex-col gap-3 p-3 rounded-lg bg-n-alpha-black2"
                >
                  <!-- IMAP Option (only if IMAP is enabled) -->
                  <label
                    v-if="hasImapEnabled"
                    class="flex items-start gap-3 p-2 rounded-md cursor-pointer hover:bg-n-alpha-black2"
                    :class="{
                      'bg-n-brand/10 ring-1 ring-n-brand':
                        formState.replyToOption === 'imap',
                    }"
                  >
                    <input
                      v-model="formState.replyToOption"
                      type="radio"
                      value="imap"
                      class="mt-0.5 w-4 h-4 border-n-weak text-n-brand focus:ring-n-brand"
                    />
                    <div class="flex-1 min-w-0">
                      <span class="text-sm font-medium text-n-slate-12">
                        {{
                          t('CAMPAIGN.EMAIL.CREATE.FORM.REPLY_TO.IMAP_OPTION')
                        }}
                      </span>
                      <span
                        class="ml-2 px-1.5 py-0.5 text-xs font-medium rounded bg-n-teal-3 text-n-teal-11"
                      >
                        {{
                          t('CAMPAIGN.EMAIL.CREATE.FORM.REPLY_TO.RECOMMENDED')
                        }}
                      </span>
                      <p class="mt-1 text-xs text-n-slate-11 truncate">
                        {{ imapEmail }}
                      </p>
                    </div>
                  </label>

                  <!-- Resend Email Option -->
                  <label
                    class="flex items-start gap-3 p-2 rounded-md cursor-pointer hover:bg-n-alpha-black2"
                    :class="{
                      'bg-n-brand/10 ring-1 ring-n-brand':
                        formState.replyToOption === 'resend',
                    }"
                  >
                    <input
                      v-model="formState.replyToOption"
                      type="radio"
                      value="resend"
                      class="mt-0.5 w-4 h-4 border-n-weak text-n-brand focus:ring-n-brand"
                    />
                    <div class="flex-1 min-w-0">
                      <span class="text-sm font-medium text-n-slate-12">
                        {{
                          t('CAMPAIGN.EMAIL.CREATE.FORM.REPLY_TO.RESEND_OPTION')
                        }}
                      </span>
                      <span
                        v-if="!hasImapEnabled"
                        class="ml-2 px-1.5 py-0.5 text-xs font-medium rounded bg-n-slate-3 text-n-slate-11"
                      >
                        {{ t('CAMPAIGN.EMAIL.CREATE.FORM.REPLY_TO.DEFAULT') }}
                      </span>
                      <p class="mt-1 text-xs text-n-slate-11 truncate">
                        {{ resendEmail || 'Select an inbox first' }}
                      </p>
                    </div>
                  </label>

                  <!-- Custom Email Option -->
                  <label
                    class="flex items-start gap-3 p-2 rounded-md cursor-pointer hover:bg-n-alpha-black2"
                    :class="{
                      'bg-n-brand/10 ring-1 ring-n-brand':
                        formState.replyToOption === 'custom',
                    }"
                  >
                    <input
                      v-model="formState.replyToOption"
                      type="radio"
                      value="custom"
                      class="mt-0.5 w-4 h-4 border-n-weak text-n-brand focus:ring-n-brand"
                    />
                    <div class="flex-1 min-w-0">
                      <span class="text-sm font-medium text-n-slate-12">
                        {{
                          t('CAMPAIGN.EMAIL.CREATE.FORM.REPLY_TO.CUSTOM_OPTION')
                        }}
                      </span>
                      <p class="mt-1 text-xs text-n-slate-11">
                        {{
                          t(
                            'CAMPAIGN.EMAIL.CREATE.FORM.REPLY_TO.CUSTOM_DESCRIPTION'
                          )
                        }}
                      </p>
                    </div>
                  </label>

                  <!-- Custom Email Input (only when custom is selected) -->
                  <div
                    v-if="formState.replyToOption === 'custom'"
                    class="mt-1 ml-7"
                  >
                    <Input
                      v-model="formState.replyToEmail"
                      :placeholder="
                        t('CAMPAIGN.EMAIL.CREATE.FORM.REPLY_TO.PLACEHOLDER')
                      "
                      :message="formErrors.replyToEmail"
                      :message-type="formErrors.replyToEmail ? 'error' : 'info'"
                      type="email"
                    />
                  </div>
                </div>
              </div>
            </div>
          </section>

          <!-- Email Content Section -->
          <section
            class="p-5 shadow bg-n-solid-2 rounded-2xl outline-1 outline outline-n-container"
          >
            <div class="flex items-center gap-2 mb-4">
              <i class="text-lg i-lucide-code text-n-slate-11" />
              <h3
                class="text-sm font-semibold tracking-wide uppercase text-n-slate-12"
              >
                {{ t('CAMPAIGN.EMAIL.CREATE_DIALOG.SECTIONS.EMAIL_CONTENT') }}
              </h3>
            </div>

            <div class="space-y-4">
              <div class="flex flex-col gap-1">
                <label
                  for="message"
                  class="mb-0.5 text-sm font-medium text-n-slate-12"
                >
                  {{ t('CAMPAIGN.EMAIL.CREATE.FORM.MESSAGE.LABEL') }}
                  <span class="text-red-500 ml-0.5">*</span>
                </label>
                <textarea
                  id="message"
                  v-model="formState.message"
                  :placeholder="
                    t('CAMPAIGN.EMAIL.CREATE.FORM.MESSAGE.PLACEHOLDER')
                  "
                  rows="24"
                  class="w-full px-3 py-3 font-mono text-sm transition-all duration-200 border rounded-lg resize-y bg-n-alpha-black2 border-n-weak text-n-slate-12 placeholder:text-n-slate-10 focus:border-n-brand focus:outline-none hover:border-n-slate-6 min-h-[400px]"
                  :class="{
                    'border-n-ruby-8 hover:border-n-ruby-9': formErrors.message,
                  }"
                />
                <p v-if="formErrors.message" class="mt-1 text-xs text-n-ruby-9">
                  {{ formErrors.message }}
                </p>
                <p class="mt-1 text-xs text-n-slate-11">
                  {{ t('CAMPAIGN.EMAIL.CREATE.FORM.MESSAGE.HELP') }}
                </p>
              </div>
            </div>
          </section>

          <!-- Audience & Schedule Section -->
          <section
            class="p-5 shadow bg-n-solid-2 rounded-2xl outline-1 outline outline-n-container"
          >
            <div class="flex items-center gap-2 mb-4">
              <i class="text-lg i-lucide-users text-n-slate-11" />
              <h3
                class="text-sm font-semibold tracking-wide uppercase text-n-slate-12"
              >
                {{
                  t('CAMPAIGN.EMAIL.CREATE_DIALOG.SECTIONS.AUDIENCE_SCHEDULE')
                }}
              </h3>
            </div>

            <div class="space-y-4">
              <!-- Audience -->
              <div class="flex flex-col gap-1">
                <label
                  for="audience"
                  class="mb-0.5 text-sm font-medium text-n-slate-12"
                >
                  {{ t('CAMPAIGN.EMAIL.CREATE.FORM.AUDIENCE.LABEL') }}
                  <span class="text-red-500 ml-0.5">*</span>
                </label>
                <TagMultiSelectComboBox
                  v-model="formState.selectedAudience"
                  :options="audienceOptions"
                  :label="t('CAMPAIGN.EMAIL.CREATE.FORM.AUDIENCE.LABEL')"
                  :placeholder="
                    t('CAMPAIGN.EMAIL.CREATE.FORM.AUDIENCE.PLACEHOLDER')
                  "
                  :has-error="!!formErrors.audience"
                  :message="formErrors.audience"
                />
              </div>

              <!-- Scheduled At -->
              <Input
                v-model="formState.scheduledAt"
                :label="t('CAMPAIGN.EMAIL.CREATE.FORM.SCHEDULED_AT.LABEL')"
                type="datetime-local"
                :min="currentDateTime"
                :placeholder="
                  t('CAMPAIGN.EMAIL.CREATE.FORM.SCHEDULED_AT.PLACEHOLDER')
                "
                :message="formErrors.scheduledAt"
                :message-type="formErrors.scheduledAt ? 'error' : 'info'"
                required
              />
            </div>
          </section>
        </div>

        <!-- Preview Panel -->
        <div class="w-[400px] flex-shrink-0 flex flex-col overflow-hidden">
          <div class="flex items-center gap-2 mb-4">
            <i class="text-lg i-lucide-eye text-n-slate-11" />
            <h3
              class="text-sm font-semibold tracking-wide uppercase text-n-slate-12"
            >
              {{ t('CAMPAIGN.EMAIL.CREATE_DIALOG.PREVIEW_TITLE') }}
            </h3>
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
                <span class="text-sm text-n-slate-12">{{
                  formState.subject ||
                  t('CAMPAIGN.EMAIL.CREATE.FORM.SUBJECT.PLACEHOLDER')
                }}</span>
              </div>
              <div class="flex items-center gap-2">
                <span class="text-xs font-medium text-n-slate-11">
                  {{ t('CAMPAIGN.EMAIL.DETAILS.REPLY_TO_LABEL') }}
                </span>
                <span class="text-xs text-n-slate-10">{{
                  selectedReplyToEmail
                }}</span>
              </div>
            </div>

            <!-- Email Body Preview -->
            <div class="h-full overflow-y-auto">
              <iframe
                :srcdoc="previewHtml"
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
        class="flex justify-end flex-shrink-0 gap-3 px-6 py-4 border-t border-n-weak"
      >
        <Button
          variant="faded"
          color="slate"
          :label="t('CAMPAIGN.EMAIL.CREATE.FORM.BUTTONS.CANCEL')"
          @click="handleCancel"
        />
        <Button
          :label="t('CAMPAIGN.EMAIL.CREATE.FORM.BUTTONS.CREATE')"
          :is-loading="isCreating"
          :disabled="isSubmitDisabled"
          @click="handleSubmit"
        />
      </div>
    </div>
  </Dialog>
</template>
