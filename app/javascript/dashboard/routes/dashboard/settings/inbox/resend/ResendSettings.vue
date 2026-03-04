<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import SettingsSection from 'dashboard/components/SettingsSection.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ResendAPI from 'dashboard/api/resend';

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
      isCheckingDomainStatus: false,
      isVerifyingDomain: false,
      isConfiguringWebhook: false,
      isSendingDns: false,
      dnsRecipientEmail: '',
      domainStatusData: null,
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
    sftpHost() {
      return window.chatwootConfig?.sftpCampaignsHost || '';
    },
    sftpPort() {
      return window.chatwootConfig?.sftpCampaignsPort || '22';
    },
    sftpCampaignsDomain() {
      const email =
        this.inbox.provider_config?.from_email || this.inbox.email || '';
      const parts = email.split('@');
      return parts.length === 2 ? parts[1] : '';
    },
    hasDomainId() {
      return !!this.inbox.provider_config?.resend_domain_id;
    },
    domainProvisioned() {
      return this.inbox.provider_config?.domain_provisioned === true;
    },
    domainStatus() {
      return (
        this.domainStatusData?.status ||
        this.inbox.provider_config?.resend_domain_status ||
        'unknown'
      );
    },
    isDomainVerified() {
      return this.domainStatus === 'verified';
    },
    dnsRecords() {
      return (
        this.domainStatusData?.records ||
        this.inbox.provider_config?.resend_dns_records ||
        []
      );
    },
    hasAutoWebhook() {
      return !!this.inbox.provider_config?.resend_webhook_id;
    },
    domainStatusBadgeClass() {
      if (this.isDomainVerified) return 'bg-n-teal-3 text-n-teal-11';
      return 'bg-n-amber-3 text-n-amber-11';
    },
    isValidDnsRecipient() {
      return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(this.dnsRecipientEmail);
    },
  },
  mounted() {
    this.fromEmail = this.currentFromEmail;
    this.fromName = this.currentFromName;
  },
  methods: {
    async checkDomainStatus() {
      this.isCheckingDomainStatus = true;
      try {
        const { data } = await ResendAPI.checkDomainStatus(this.inbox.id);
        this.domainStatusData = data;
        if (data.status === 'verified') {
          useAlert(
            this.$t('INBOX_MGMT.RESEND_SETTINGS.DOMAIN_VERIFIED_SUCCESS')
          );
        }
      } catch (error) {
        useAlert(
          error?.response?.data?.error ||
            this.$t('INBOX_MGMT.RESEND_SETTINGS.DOMAIN_STATUS_ERROR')
        );
      } finally {
        this.isCheckingDomainStatus = false;
      }
    },
    async verifyDomain() {
      this.isVerifyingDomain = true;
      try {
        await ResendAPI.verifyDomain(this.inbox.id);
        useAlert(this.$t('INBOX_MGMT.RESEND_SETTINGS.VERIFY_TRIGGERED'));
        setTimeout(() => this.checkDomainStatus(), 3000);
      } catch (error) {
        useAlert(
          error?.response?.data?.error ||
            this.$t('INBOX_MGMT.RESEND_SETTINGS.VERIFY_ERROR')
        );
      } finally {
        this.isVerifyingDomain = false;
      }
    },
    async sendDnsInstructions() {
      if (!this.dnsRecipientEmail) return;
      this.isSendingDns = true;
      try {
        await ResendAPI.sendDnsInstructions({
          inbox_id: this.inbox.id,
          recipient_email: this.dnsRecipientEmail,
        });
        useAlert(this.$t('INBOX_MGMT.RESEND_SETTINGS.DNS_SENT_SUCCESS'));
        this.dnsRecipientEmail = '';
      } catch (error) {
        useAlert(
          error?.response?.data?.error ||
            this.$t('INBOX_MGMT.RESEND_SETTINGS.DNS_SENT_ERROR')
        );
      } finally {
        this.isSendingDns = false;
      }
    },
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
    async configureWebhook() {
      this.isConfiguringWebhook = true;
      try {
        await ResendAPI.configureWebhook(this.inbox.id);
        useAlert(
          this.$t('INBOX_MGMT.RESEND_SETTINGS.WEBHOOK_CONFIGURE_SUCCESS')
        );
        await this.$store.dispatch('inboxes/get', { inboxId: this.inbox.id });
      } catch (error) {
        useAlert(
          error?.response?.data?.error ||
            this.$t('INBOX_MGMT.RESEND_SETTINGS.WEBHOOK_CONFIGURE_ERROR')
        );
      } finally {
        this.isConfiguringWebhook = false;
      }
    },
    async copyDnsValue(value) {
      await copyTextToClipboard(value);
      useAlert(this.$t('CONTACT_PANEL.COPY_SUCCESSFUL'));
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
    <!-- Domain Status (only for provisioned domains) -->
    <SettingsSection
      v-if="hasDomainId"
      :title="$t('INBOX_MGMT.RESEND_SETTINGS.DOMAIN_STATUS_TITLE')"
      :sub-title="$t('INBOX_MGMT.RESEND_SETTINGS.DOMAIN_STATUS_SUBTITLE')"
    >
      <div class="flex flex-col gap-4">
        <div class="flex items-center gap-3">
          <span
            class="inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium"
            :class="domainStatusBadgeClass"
          >
            {{
              isDomainVerified
                ? $t('INBOX_MGMT.RESEND_SETTINGS.STATUS_VERIFIED')
                : $t('INBOX_MGMT.RESEND_SETTINGS.STATUS_PENDING')
            }}
          </span>
          <span class="text-sm text-n-slate-11">
            {{ sftpCampaignsDomain }}
          </span>
        </div>

        <div class="flex gap-2">
          <NextButton
            :is-loading="isCheckingDomainStatus"
            @click="checkDomainStatus"
          >
            {{ $t('INBOX_MGMT.RESEND_SETTINGS.CHECK_STATUS') }}
          </NextButton>
          <NextButton
            v-if="!isDomainVerified"
            :is-loading="isVerifyingDomain"
            @click="verifyDomain"
          >
            {{ $t('INBOX_MGMT.RESEND_SETTINGS.VERIFY_RECORDS') }}
          </NextButton>
        </div>

        <!-- DNS Records Table -->
        <div v-if="dnsRecords.length > 0" class="mt-2">
          <h4 class="text-sm font-medium text-n-slate-12 mb-1">
            {{ $t('INBOX_MGMT.RESEND_SETTINGS.DNS_RECORDS_TITLE') }}
          </h4>
          <p class="text-xs text-n-slate-11 mb-2">
            {{ $t('INBOX_MGMT.RESEND_SETTINGS.DNS_RECORDS_INSTRUCTIONS') }}
          </p>
          <div class="overflow-x-auto rounded-lg border border-n-weak">
            <table class="w-full text-xs">
              <thead>
                <tr class="bg-n-background">
                  <th class="px-3 py-2 text-left font-medium text-n-slate-11">
                    {{ $t('INBOX_MGMT.RESEND_SETTINGS.DNS_TYPE') }}
                  </th>
                  <th class="px-3 py-2 text-left font-medium text-n-slate-11">
                    {{ $t('INBOX_MGMT.RESEND_SETTINGS.DNS_NAME') }}
                  </th>
                  <th class="px-3 py-2 text-left font-medium text-n-slate-11">
                    {{ $t('INBOX_MGMT.RESEND_SETTINGS.DNS_VALUE') }}
                  </th>
                  <th class="px-3 py-2 text-left font-medium text-n-slate-11">
                    {{ $t('INBOX_MGMT.RESEND_SETTINGS.DNS_PRIORITY') }}
                  </th>
                  <th class="px-3 py-2 text-left font-medium text-n-slate-11">
                    {{ $t('INBOX_MGMT.RESEND_SETTINGS.DNS_STATUS') }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="(record, idx) in dnsRecords"
                  :key="idx"
                  class="border-t border-n-weak"
                >
                  <td class="px-3 py-2 font-mono">
                    {{ record.record_type || record.type }}
                  </td>
                  <td class="px-3 py-2 font-mono break-all max-w-[200px]">
                    <div class="group flex items-start gap-1">
                      <span class="flex-1">{{ record.name }}</span>
                      <NextButton
                        ghost
                        xs
                        slate
                        class="invisible shrink-0 group-hover:visible"
                        icon="i-lucide-clipboard"
                        @click="copyDnsValue(record.name)"
                      />
                    </div>
                  </td>
                  <td class="px-3 py-2 font-mono break-all max-w-[300px]">
                    <div class="group flex items-start gap-1">
                      <span class="flex-1">{{ record.value }}</span>
                      <NextButton
                        ghost
                        xs
                        slate
                        class="invisible shrink-0 group-hover:visible"
                        icon="i-lucide-clipboard"
                        @click="copyDnsValue(record.value)"
                      />
                    </div>
                  </td>
                  <td class="px-3 py-2 font-mono text-center">
                    <div class="group relative inline-block">
                      {{ record.priority ?? '—' }}
                      <NextButton
                        v-if="record.priority != null"
                        ghost
                        xs
                        slate
                        class="invisible absolute -right-6 top-1/2 -translate-y-1/2 group-hover:visible"
                        icon="i-lucide-clipboard"
                        @click="copyDnsValue(String(record.priority))"
                      />
                    </div>
                  </td>
                  <td class="px-3 py-2">
                    <span
                      class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium"
                      :class="
                        record.status === 'verified'
                          ? 'bg-n-teal-3 text-n-teal-11'
                          : 'bg-n-amber-3 text-n-amber-11'
                      "
                    >
                      {{ record.status || 'pending' }}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Send DNS Instructions -->
        <div class="mt-2">
          <h4 class="text-sm font-medium text-n-slate-12 mb-2">
            {{ $t('INBOX_MGMT.RESEND_SETTINGS.SEND_DNS_TITLE') }}
          </h4>
          <div class="flex items-center gap-2">
            <woot-input
              v-model="dnsRecipientEmail"
              type="email"
              class="flex-1 [&>input]:!mb-0"
              :placeholder="
                $t('INBOX_MGMT.RESEND_SETTINGS.SEND_DNS_PLACEHOLDER')
              "
            />
            <NextButton
              :is-loading="isSendingDns"
              :disabled="!isValidDnsRecipient"
              @click="sendDnsInstructions"
            >
              {{ $t('INBOX_MGMT.RESEND_SETTINGS.SEND_DNS_BUTTON') }}
            </NextButton>
          </div>
        </div>
      </div>
    </SettingsSection>

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

    <!-- Webhook Section -->
    <SettingsSection
      :title="$t('INBOX_MGMT.RESEND_SETTINGS.WEBHOOK_URL_TITLE')"
      :sub-title="
        hasAutoWebhook
          ? $t('INBOX_MGMT.RESEND_SETTINGS.WEBHOOK_AUTO_SUBTITLE')
          : $t('INBOX_MGMT.RESEND_SETTINGS.WEBHOOK_URL_SUBTITLE')
      "
    >
      <div class="flex flex-col gap-3">
        <div class="flex items-center gap-2">
          <span
            class="inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium"
            :class="
              hasAutoWebhook
                ? 'bg-n-teal-3 text-n-teal-11'
                : 'bg-n-amber-3 text-n-amber-11'
            "
          >
            {{
              hasAutoWebhook
                ? $t('INBOX_MGMT.RESEND_SETTINGS.WEBHOOK_CONFIGURED')
                : $t('INBOX_MGMT.RESEND_SETTINGS.WEBHOOK_MANUAL')
            }}
          </span>
          <NextButton
            v-if="!hasAutoWebhook"
            xs
            :is-loading="isConfiguringWebhook"
            @click="configureWebhook"
          >
            {{ $t('INBOX_MGMT.RESEND_SETTINGS.CONFIGURE_WEBHOOK') }}
          </NextButton>
        </div>
        <woot-code :script="webhookUrl" lang="html" />
      </div>
    </SettingsSection>

    <!-- Current Signing Secret (if configured) -->
    <SettingsSection
      v-if="currentSigningSecret"
      :title="$t('INBOX_MGMT.RESEND_SETTINGS.SIGNING_SECRET_TITLE')"
      :sub-title="$t('INBOX_MGMT.RESEND_SETTINGS.SIGNING_SECRET_SUBTITLE')"
    >
      <woot-code :script="currentSigningSecret" />
    </SettingsSection>

    <!-- Update Signing Secret (only for manual webhooks) -->
    <SettingsSection
      v-if="!hasAutoWebhook"
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

        <!-- SFTP Upload Instructions -->
        <div
          v-if="currentSftpCampaignsEnabled && sftpHost"
          class="flex flex-col gap-3 p-4 rounded-lg bg-n-background border border-n-weak"
        >
          <h4 class="text-sm font-medium text-n-slate-12">
            {{ $t('INBOX_MGMT.RESEND_SETTINGS.SFTP_UPLOAD_TITLE') }}
          </h4>
          <div class="flex flex-col gap-2 text-xs text-n-slate-11">
            <div class="flex items-center gap-2">
              <strong class="min-w-[80px]">{{
                $t('INBOX_MGMT.RESEND_SETTINGS.SFTP_HOST_LABEL')
              }}</strong>
              <code
                class="rounded bg-n-alpha-1 px-2 py-0.5 font-mono text-n-slate-12"
              >
                {{ sftpHost }}
              </code>
            </div>
            <div class="flex items-center gap-2">
              <strong class="min-w-[80px]">{{
                $t('INBOX_MGMT.RESEND_SETTINGS.SFTP_PORT_LABEL')
              }}</strong>
              <code
                class="rounded bg-n-alpha-1 px-2 py-0.5 font-mono text-n-slate-12"
              >
                {{ sftpPort }}
              </code>
            </div>
            <div class="flex items-center gap-2">
              <strong class="min-w-[80px]">{{
                $t('INBOX_MGMT.RESEND_SETTINGS.SFTP_PATH_LABEL')
              }}</strong>
              <code
                class="rounded bg-n-alpha-1 px-2 py-0.5 font-mono text-n-slate-12"
              >
                {{ $t('INBOX_MGMT.RESEND_SETTINGS.SFTP_PATH_VALUE') }}
              </code>
            </div>
          </div>
          <div class="mt-1">
            <p class="text-xs text-n-slate-11 mb-1">
              {{ $t('INBOX_MGMT.RESEND_SETTINGS.SFTP_UPLOAD_EXAMPLE') }}
            </p>
            <!-- prettier-ignore -->
            <pre
              class="overflow-x-auto rounded-lg bg-n-alpha-1 p-3 font-mono text-xs text-n-slate-12 border border-n-weak"
            >{{ $t('INBOX_MGMT.RESEND_SETTINGS.SFTP_UPLOAD_COMMAND', { port: sftpPort, host: sftpHost }) }}</pre>
          </div>
        </div>
      </div>
    </SettingsSection>
  </div>
</template>
