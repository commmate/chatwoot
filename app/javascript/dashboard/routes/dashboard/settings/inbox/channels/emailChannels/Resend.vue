<script setup>
import { ref, computed, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, email, minLength, helpers } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import { useRouter } from 'vue-router';
import ResendAPI from 'dashboard/api/resend';
import PageHeader from '../../../SettingsSubPageHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const RESEND_REGIONS = [
  { id: 'us-east-1', label: 'N. Virginia (us-east-1)' },
  { id: 'eu-west-1', label: 'Ireland (eu-west-1)' },
  { id: 'sa-east-1', label: 'São Paulo (sa-east-1)' },
  { id: 'ap-northeast-1', label: 'Tokyo (ap-northeast-1)' },
];

const DOMAIN_REGEX =
  /^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$/i;

const store = useStore();
const router = useRouter();
const { t } = useI18n();

const masterKeyConfigured = window.chatwootConfig?.resendMasterKeyConfigured;

const mode = ref('existing');
const channelName = ref('');
const apiKey = ref('');
const fromEmail = ref('');
const fromName = ref('');
const domainName = ref('');
const region = ref('eu-west-1');
const isSubmitting = ref(false);
const duplicateDomainError = ref('');

const startsWithRe = helpers.withMessage(
  () => t('INBOX_MGMT.ADD.RESEND.API_KEY.FORMAT_ERROR'),
  value => !value || value.startsWith('re_')
);

const validDomain = helpers.withMessage(
  () => t('INBOX_MGMT.ADD.RESEND.NEW_DOMAIN.DOMAIN_NAME.FORMAT_ERROR'),
  value => !value || DOMAIN_REGEX.test(value)
);

const existingRules = {
  channelName: { required, minLength: minLength(2) },
  apiKey: { required, startsWithRe },
  fromEmail: { required, email },
};

const newDomainRules = {
  channelName: { required, minLength: minLength(2) },
  domainName: { required, validDomain },
  fromEmail: { required, email },
};

const rules = computed(() =>
  mode.value === 'existing' ? existingRules : newDomainRules
);

const v$ = useVuelidate(rules, {
  channelName,
  apiKey,
  fromEmail,
  domainName,
});

const uiFlags = computed(() => store.getters['inboxes/getUIFlags']);

watch(domainName, newVal => {
  duplicateDomainError.value = '';
  if (newVal && DOMAIN_REGEX.test(newVal)) {
    fromEmail.value = `noreply@${newVal}`;
  }
});

watch(mode, () => {
  apiKey.value = '';
  fromEmail.value = '';
  domainName.value = '';
  duplicateDomainError.value = '';
  v$.value.$reset();
});

let domainCheckTimeout = null;
function onDomainBlur() {
  v$.value.domainName?.$touch();
  if (!domainName.value || !DOMAIN_REGEX.test(domainName.value)) return;

  clearTimeout(domainCheckTimeout);
  domainCheckTimeout = setTimeout(async () => {
    try {
      const { data } = await ResendAPI.listDomains();
      const existing = (data?.data || []).find(
        d => d.name === domainName.value.toLowerCase()
      );
      if (existing) {
        duplicateDomainError.value = t(
          'INBOX_MGMT.ADD.RESEND.NEW_DOMAIN.DOMAIN_NAME.DUPLICATE_ERROR',
          { domain: domainName.value }
        );
      }
    } catch {
      // Master key may not be configured or API error — skip check
    }
  }, 500);
}

async function createExistingDomain() {
  try {
    const emailChannel = await store.dispatch('inboxes/createChannel', {
      name: channelName.value.trim(),
      channel: {
        type: 'email',
        email: fromEmail.value,
        provider: 'resend',
        provider_config: {
          api_key: apiKey.value,
          from_email: fromEmail.value,
          from_name: fromName.value || channelName.value,
        },
      },
    });

    router.replace({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: emailChannel.id },
    });
  } catch (error) {
    useAlert(error?.message || t('INBOX_MGMT.ADD.RESEND.API.ERROR_MESSAGE'));
  }
}

async function createNewDomain() {
  if (duplicateDomainError.value) return;

  try {
    const { data } = await ResendAPI.provisionDomain({
      domain_name: domainName.value.toLowerCase().trim(),
      region: region.value,
      from_email: fromEmail.value,
      from_name: fromName.value || channelName.value,
      channel_name: channelName.value.trim(),
    });

    if (data.webhook_error) {
      useAlert(t('INBOX_MGMT.ADD.RESEND.NEW_DOMAIN.WEBHOOK_WARNING'));
    }

    router.replace({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: data.inbox.id },
    });
  } catch (error) {
    const msg =
      error?.response?.data?.error ||
      error?.message ||
      t('INBOX_MGMT.ADD.RESEND.API.ERROR_MESSAGE');
    useAlert(msg);
  }
}

async function createChannel() {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  isSubmitting.value = true;
  try {
    if (mode.value === 'existing') {
      await createExistingDomain();
    } else {
      await createNewDomain();
    }
  } finally {
    isSubmitting.value = false;
  }
}
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.RESEND.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.RESEND.DESC')"
    />
    <form
      class="flex flex-wrap flex-col mx-0 max-w-lg"
      @submit.prevent="createChannel"
    >
      <!-- Mode selector (only when master key is configured) -->
      <div v-if="masterKeyConfigured" class="flex gap-4 mb-6">
        <label
          class="flex items-center gap-2 cursor-pointer rounded-lg border px-4 py-3 transition-colors"
          :class="
            mode === 'existing'
              ? 'border-woot-500 bg-woot-25 dark:bg-woot-800/20'
              : 'border-n-100 dark:border-n-700'
          "
        >
          <input
            v-model="mode"
            type="radio"
            value="existing"
            class="accent-woot-500"
          />
          <div>
            <span class="text-sm font-medium text-n-800 dark:text-n-100">
              {{ $t('INBOX_MGMT.ADD.RESEND.MODE_EXISTING') }}
            </span>
            <p class="text-xs text-n-500 mt-0.5">
              {{ $t('INBOX_MGMT.ADD.RESEND.MODE_EXISTING_DESC') }}
            </p>
          </div>
        </label>
        <label
          class="flex items-center gap-2 cursor-pointer rounded-lg border px-4 py-3 transition-colors"
          :class="
            mode === 'new'
              ? 'border-woot-500 bg-woot-25 dark:bg-woot-800/20'
              : 'border-n-100 dark:border-n-700'
          "
        >
          <input
            v-model="mode"
            type="radio"
            value="new"
            class="accent-woot-500"
          />
          <div>
            <span class="text-sm font-medium text-n-800 dark:text-n-100">
              {{ $t('INBOX_MGMT.ADD.RESEND.MODE_NEW') }}
            </span>
            <p class="text-xs text-n-500 mt-0.5">
              {{ $t('INBOX_MGMT.ADD.RESEND.MODE_NEW_DESC') }}
            </p>
          </div>
        </label>
      </div>

      <!-- Channel Name (both modes) -->
      <div class="flex-shrink-0 flex-grow-0 mb-4">
        <label :class="{ error: v$.channelName.$error }">
          {{ $t('INBOX_MGMT.ADD.RESEND.CHANNEL_NAME.LABEL') }}
          <input
            v-model="channelName"
            type="text"
            :placeholder="$t('INBOX_MGMT.ADD.RESEND.CHANNEL_NAME.PLACEHOLDER')"
            @blur="v$.channelName.$touch"
          />
          <span v-if="v$.channelName.$error" class="message">
            {{ $t('INBOX_MGMT.ADD.RESEND.CHANNEL_NAME.ERROR') }}
          </span>
        </label>
      </div>

      <!-- API Key (existing mode only) -->
      <div v-if="mode === 'existing'" class="flex-shrink-0 flex-grow-0 mb-4">
        <label :class="{ error: v$.apiKey.$error }">
          {{ $t('INBOX_MGMT.ADD.RESEND.API_KEY.LABEL') }}
          <input
            v-model="apiKey"
            type="password"
            :placeholder="$t('INBOX_MGMT.ADD.RESEND.API_KEY.PLACEHOLDER')"
            @blur="v$.apiKey.$touch"
          />
          <p class="help-text">
            {{ $t('INBOX_MGMT.ADD.RESEND.API_KEY.SUBTITLE') }}
          </p>
          <span v-if="v$.apiKey.$error" class="message">
            {{
              v$.apiKey.$errors[0]?.$message ||
              $t('INBOX_MGMT.ADD.RESEND.API_KEY.ERROR')
            }}
          </span>
        </label>
      </div>

      <!-- Domain Name (new domain mode) -->
      <div v-if="mode === 'new'" class="flex-shrink-0 flex-grow-0 mb-4">
        <label :class="{ error: v$.domainName.$error || duplicateDomainError }">
          {{ $t('INBOX_MGMT.ADD.RESEND.NEW_DOMAIN.DOMAIN_NAME.LABEL') }}
          <input
            v-model="domainName"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.RESEND.NEW_DOMAIN.DOMAIN_NAME.PLACEHOLDER')
            "
            @blur="onDomainBlur"
          />
          <p class="help-text">
            {{ $t('INBOX_MGMT.ADD.RESEND.NEW_DOMAIN.DOMAIN_NAME.SUBTITLE') }}
          </p>
          <span v-if="v$.domainName.$error" class="message">
            {{
              v$.domainName.$errors[0]?.$message ||
              $t('INBOX_MGMT.ADD.RESEND.NEW_DOMAIN.DOMAIN_NAME.ERROR')
            }}
          </span>
          <span v-else-if="duplicateDomainError" class="message">
            {{ duplicateDomainError }}
          </span>
        </label>
      </div>

      <!-- Region (new domain mode) -->
      <div v-if="mode === 'new'" class="flex-shrink-0 flex-grow-0 mb-4">
        <label>
          {{ $t('INBOX_MGMT.ADD.RESEND.NEW_DOMAIN.REGION.LABEL') }}
          <select v-model="region" class="mb-0">
            <option v-for="r in RESEND_REGIONS" :key="r.id" :value="r.id">
              {{ r.label }}
            </option>
          </select>
          <p class="help-text">
            {{ $t('INBOX_MGMT.ADD.RESEND.NEW_DOMAIN.REGION.SUBTITLE') }}
          </p>
        </label>
      </div>

      <!-- From Email (both modes) -->
      <div class="flex-shrink-0 flex-grow-0 mb-4">
        <label :class="{ error: v$.fromEmail.$error }">
          {{ $t('INBOX_MGMT.ADD.RESEND.FROM_EMAIL.LABEL') }}
          <input
            v-model="fromEmail"
            type="text"
            :placeholder="$t('INBOX_MGMT.ADD.RESEND.FROM_EMAIL.PLACEHOLDER')"
            @blur="v$.fromEmail.$touch"
          />
          <p class="help-text">
            {{
              mode === 'new'
                ? $t('INBOX_MGMT.ADD.RESEND.NEW_DOMAIN.FROM_EMAIL_SUBTITLE')
                : $t('INBOX_MGMT.ADD.RESEND.FROM_EMAIL.SUBTITLE')
            }}
          </p>
          <span v-if="v$.fromEmail.$error" class="message">
            {{ $t('INBOX_MGMT.ADD.RESEND.FROM_EMAIL.ERROR') }}
          </span>
        </label>
      </div>

      <!-- From Name (both modes) -->
      <div class="flex-shrink-0 flex-grow-0 mb-4">
        <label>
          {{ $t('INBOX_MGMT.ADD.RESEND.FROM_NAME.LABEL') }}
          <input
            v-model="fromName"
            type="text"
            :placeholder="$t('INBOX_MGMT.ADD.RESEND.FROM_NAME.PLACEHOLDER')"
          />
          <p class="help-text">
            {{ $t('INBOX_MGMT.ADD.RESEND.FROM_NAME.SUBTITLE') }}
          </p>
        </label>
      </div>

      <div class="w-full mt-4">
        <NextButton
          :is-loading="isSubmitting || uiFlags.isCreating"
          type="submit"
          solid
          blue
          :label="$t('INBOX_MGMT.ADD.RESEND.SUBMIT_BUTTON')"
        />
      </div>
    </form>
  </div>
</template>
