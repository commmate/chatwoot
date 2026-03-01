<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import SettingsSection from 'dashboard/components/SettingsSection.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    SettingsSection,
    NextButton,
  },
  props: {
    inbox: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      apiKey: '',
      fromEmail: '',
      fromName: '',
      signingSecret: '',
      isUpdatingApiKey: false,
      isUpdatingSenderSettings: false,
      isUpdatingSigningSecret: false,
      isUpdatingSftpCampaigns: false,
    };
  },
  computed: {
    ...mapGetters({ currentAccount: 'getCurrentAccount' }),
    accountName() {
      return this.currentAccount?.name || '';
    },
    webhookUrl() {
      return this.inbox.callback_webhook_url;
    },
    currentApiKey() {
      return this.inbox.provider_config?.api_key || '';
    },
    currentFromEmail() {
      return this.inbox.provider_config?.from_email || this.inbox.email || '';
    },
    currentFromName() {
      return this.inbox.provider_config?.from_name || '';
    },
    currentSigningSecret() {
      return this.inbox.provider_config?.webhook_signing_secret;
    },
    showSftpToggle() {
      return (
        window.chatwootConfig?.resendEnabled === 'true' &&
        window.chatwootConfig?.sftpCampaignsEnabled === 'true'
      );
    },
    currentSftpCampaignsEnabled() {
      return this.inbox.provider_config?.sftp_campaigns_enabled === true;
    },
    sftpCampaignsDomain() {
      const email =
        this.inbox.provider_config?.from_email || this.inbox.email || '';
      const parts = email.split('@');
      return parts.length === 2 ? parts[1] : '';
    },
  },
  mounted() {
    // Initialize form fields with current values
    this.fromEmail = this.currentFromEmail;
    this.fromName = this.currentFromName;
  },
  methods: {
    async updateApiKey() {
      this.isUpdatingApiKey = true;
      try {
        const payload = {
          id: this.inbox.id,
          formData: false,
          channel: {
            provider_config: {
              ...this.inbox.provider_config,
              api_key: this.apiKey,
            },
          },
        };
        await this.$store.dispatch('inboxes/updateInbox', payload);
        this.apiKey = '';
        useAlert(this.$t('INBOX_MGMT.RESEND_SETTINGS.API_KEY_SAVED'));
      } catch (error) {
        useAlert(this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      } finally {
        this.isUpdatingApiKey = false;
      }
    },
    async updateSenderSettings() {
      this.isUpdatingSenderSettings = true;
      try {
        const payload = {
          id: this.inbox.id,
          formData: false,
          channel: {
            provider_config: {
              ...this.inbox.provider_config,
              from_email: this.fromEmail,
              from_name: this.fromName,
            },
          },
        };
        await this.$store.dispatch('inboxes/updateInbox', payload);
        useAlert(this.$t('INBOX_MGMT.RESEND_SETTINGS.SENDER_SETTINGS_SAVED'));
      } catch (error) {
        useAlert(this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      } finally {
        this.isUpdatingSenderSettings = false;
      }
    },
    async updateSigningSecret() {
      this.isUpdatingSigningSecret = true;
      try {
        const payload = {
          id: this.inbox.id,
          formData: false,
          channel: {
            provider_config: {
              ...this.inbox.provider_config,
              webhook_signing_secret: this.signingSecret,
            },
          },
        };
        await this.$store.dispatch('inboxes/updateInbox', payload);
        this.signingSecret = '';
        useAlert(this.$t('INBOX_MGMT.RESEND_SETTINGS.SIGNING_SECRET_SAVED'));
      } catch (error) {
        useAlert(this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      } finally {
        this.isUpdatingSigningSecret = false;
      }
    },
    async updateSftpCampaigns(enabled) {
      this.isUpdatingSftpCampaigns = true;
      try {
        const payload = {
          id: this.inbox.id,
          formData: false,
          channel: {
            provider_config: {
              ...this.inbox.provider_config,
              sftp_campaigns_enabled: enabled,
            },
          },
        };
        await this.$store.dispatch('inboxes/updateInbox', payload);
        useAlert(this.$t('INBOX_MGMT.RESEND_SETTINGS.SFTP_CAMPAIGNS_SAVED'));
      } catch (error) {
        useAlert(this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      } finally {
        this.isUpdatingSftpCampaigns = false;
      }
    },
  },
};
</script>

<template>
  <div class="mx-8">
    <!-- Sender Settings (From Email & From Name) - TOP SECTION -->
    <SettingsSection
      :title="$t('INBOX_MGMT.RESEND_SETTINGS.SENDER_SETTINGS_TITLE')"
      :sub-title="$t('INBOX_MGMT.RESEND_SETTINGS.SENDER_SETTINGS_SUBTITLE')"
    >
      <div class="flex flex-col gap-4">
        <div>
          <label class="mb-1 block text-sm font-medium text-n-slate-12">
            {{ $t('INBOX_MGMT.RESEND_SETTINGS.FROM_EMAIL_LABEL') }}
          </label>
          <woot-input
            v-model="fromEmail"
            type="email"
            class="[&>input]:!mb-0"
            :placeholder="
              $t('INBOX_MGMT.RESEND_SETTINGS.FROM_EMAIL_PLACEHOLDER')
            "
          />
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium text-n-slate-12">
            {{ $t('INBOX_MGMT.RESEND_SETTINGS.FROM_NAME_LABEL') }}
          </label>
          <woot-input
            v-model="fromName"
            type="text"
            class="[&>input]:!mb-0"
            :placeholder="
              $t('INBOX_MGMT.RESEND_SETTINGS.FROM_NAME_PLACEHOLDER')
            "
          />
        </div>
        <div>
          <NextButton
            :is-loading="isUpdatingSenderSettings"
            @click="updateSenderSettings"
          >
            {{ $t('INBOX_MGMT.RESEND_SETTINGS.UPDATE_SENDER_SETTINGS') }}
          </NextButton>
        </div>
      </div>
    </SettingsSection>

    <!-- SFTP Campaigns (only when both Resend and SFTP Campaigns are enabled globally) -->
    <SettingsSection
      v-if="showSftpToggle"
      :title="$t('INBOX_MGMT.RESEND_SETTINGS.SFTP_CAMPAIGNS_TITLE')"
      :sub-title="$t('INBOX_MGMT.RESEND_SETTINGS.SFTP_CAMPAIGNS_SUBTITLE')"
    >
      <div class="flex flex-col gap-4">
        <div class="flex items-center gap-2">
          <input
            :id="'sftp-campaigns-' + inbox.id"
            type="checkbox"
            class="h-4 w-4 rounded border-n-slate-8"
            :checked="currentSftpCampaignsEnabled"
            :disabled="isUpdatingSftpCampaigns"
            @change="updateSftpCampaigns($event.target.checked)"
          />
          <label
            :for="'sftp-campaigns-' + inbox.id"
            class="text-sm font-medium text-n-slate-12"
          >
            {{ $t('INBOX_MGMT.RESEND_SETTINGS.SFTP_CAMPAIGNS_ENABLED_LABEL') }}
          </label>
        </div>
        <div
          v-if="currentSftpCampaignsEnabled && sftpCampaignsDomain"
          class="flex flex-col gap-2 p-3 rounded-lg bg-n-amber-2 border border-n-amber-6"
        >
          <p class="text-sm text-n-slate-12">
            {{
              $t('INBOX_MGMT.RESEND_SETTINGS.SFTP_CAMPAIGNS_INFO', {
                domain: sftpCampaignsDomain,
              })
            }}
          </p>
          <div class="flex flex-col gap-1 text-xs text-n-slate-11">
            <span>
              <strong>{{
                $t('INBOX_MGMT.RESEND_SETTINGS.SFTP_MATCH_DOMAIN')
              }}</strong>
              {{ sftpCampaignsDomain }}
            </span>
            <span>
              <strong>{{
                $t('INBOX_MGMT.RESEND_SETTINGS.SFTP_MATCH_COMPANY')
              }}</strong>
              {{ accountName || '—' }}
            </span>
          </div>
        </div>
      </div>
    </SettingsSection>

    <!-- Current API Key (read-only display) -->
    <SettingsSection
      :title="$t('INBOX_MGMT.RESEND_SETTINGS.API_KEY_TITLE')"
      :sub-title="$t('INBOX_MGMT.RESEND_SETTINGS.API_KEY_SUBTITLE')"
    >
      <woot-code v-if="currentApiKey" :script="currentApiKey" />
      <p v-else class="text-sm text-n-slate-11">
        {{ $t('INBOX_MGMT.RESEND_SETTINGS.API_KEY_NOT_CONFIGURED') }}
      </p>
    </SettingsSection>

    <!-- Update API Key -->
    <SettingsSection
      :title="$t('INBOX_MGMT.RESEND_SETTINGS.UPDATE_API_KEY_TITLE')"
      :sub-title="$t('INBOX_MGMT.RESEND_SETTINGS.UPDATE_API_KEY_SUBTITLE')"
    >
      <div class="flex flex-1 items-center gap-2">
        <woot-input
          v-model="apiKey"
          type="text"
          class="flex-1 [&>input]:!mb-0"
          :placeholder="$t('INBOX_MGMT.RESEND_SETTINGS.API_KEY_PLACEHOLDER')"
        />
        <NextButton
          :is-loading="isUpdatingApiKey"
          :disabled="!apiKey"
          @click="updateApiKey"
        >
          {{ $t('INBOX_MGMT.RESEND_SETTINGS.UPDATE_API_KEY') }}
        </NextButton>
      </div>
    </SettingsSection>

    <!-- Webhook URL -->
    <SettingsSection
      :title="$t('INBOX_MGMT.RESEND_SETTINGS.WEBHOOK_URL_TITLE')"
      :sub-title="$t('INBOX_MGMT.RESEND_SETTINGS.WEBHOOK_URL_SUBTITLE')"
    >
      <woot-code :script="webhookUrl" lang="html" />
    </SettingsSection>

    <!-- Current Signing Secret (if configured) -->
    <SettingsSection
      v-if="currentSigningSecret"
      :title="$t('INBOX_MGMT.RESEND_SETTINGS.SIGNING_SECRET_TITLE')"
      :sub-title="$t('INBOX_MGMT.RESEND_SETTINGS.SIGNING_SECRET_SUBTITLE')"
    >
      <woot-code :script="currentSigningSecret" />
    </SettingsSection>

    <!-- Update Signing Secret -->
    <SettingsSection
      :title="$t('INBOX_MGMT.RESEND_SETTINGS.UPDATE_SIGNING_SECRET_TITLE')"
      :sub-title="
        $t('INBOX_MGMT.RESEND_SETTINGS.UPDATE_SIGNING_SECRET_SUBTITLE')
      "
    >
      <div class="flex flex-1 items-center gap-2">
        <woot-input
          v-model="signingSecret"
          type="text"
          class="flex-1 [&>input]:!mb-0"
          :placeholder="
            $t('INBOX_MGMT.RESEND_SETTINGS.SIGNING_SECRET_PLACEHOLDER')
          "
        />
        <NextButton
          :is-loading="isUpdatingSigningSecret"
          :disabled="!signingSecret"
          @click="updateSigningSecret"
        >
          {{ $t('INBOX_MGMT.RESEND_SETTINGS.UPDATE_SIGNING_SECRET') }}
        </NextButton>
      </div>
    </SettingsSection>
  </div>
</template>
