<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import EvolutionAPI from 'dashboard/api/evolution';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'shared/components/Spinner.vue';

const POLL_INTERVAL = 3000; // Poll every 3 seconds

export default {
  components: {
    NextButton,
    Spinner,
  },
  data() {
    return {
      isLoading: true,
      isEnablingIntegration: false,
      isRefreshingQR: false,
      inbox: null,
      connectionState: null,
      qrCode: null,
      pollTimer: null,
      error: null,
    };
  },
  computed: {
    ...mapGetters({
      currentAccountId: 'getCurrentAccountId',
    }),
    inboxId() {
      return this.$route.params.inbox_id;
    },
    isConnected() {
      return this.connectionState?.instance?.state === 'open';
    },
    connectionStatus() {
      if (!this.connectionState) return 'unknown';
      return this.connectionState?.instance?.state || 'disconnected';
    },
    statusColor() {
      switch (this.connectionStatus) {
        case 'open':
          return 'bg-g-500';
        case 'connecting':
          return 'bg-y-500';
        default:
          return 'bg-r-500';
      }
    },
    statusLabel() {
      return this.$t(
        `INBOX_MGMT.ADD.EVOLUTION.CONNECT.STATUS.${this.connectionStatus.toUpperCase()}`
      );
    },
    evolutionInstanceName() {
      return this.inbox?.additional_attributes?.evolution_instance_name;
    },
  },
  mounted() {
    this.fetchInboxAndConnect();
  },
  beforeUnmount() {
    this.stopPolling();
  },
  methods: {
    async fetchInboxAndConnect() {
      this.isLoading = true;
      this.error = null;

      try {
        // Fetch inbox details
        await this.$store.dispatch('inboxes/get', this.inboxId);
        this.inbox = this.$store.getters['inboxes/getInbox'](this.inboxId);

        if (!this.inbox) {
          throw new Error('Inbox not found');
        }

        // Verify this is a Baileys inbox
        const channel = this.inbox.additional_attributes?.evolution_channel;
        if (channel !== 'baileys') {
          // Not a Baileys inbox, redirect to add agents
          this.$router.replace({
            name: 'settings_inboxes_add_agents',
            params: {
              page: 'new',
              inbox_id: this.inboxId,
            },
          });
          return;
        }

        // Get initial connection state
        await this.refreshConnectionState();

        // If not connected, get QR code and start polling
        if (!this.isConnected) {
          await this.fetchQRCode();
          this.startPolling();
        }
      } catch (err) {
        this.error = err.response?.data?.error || err.message;
        useAlert(this.error);
      } finally {
        this.isLoading = false;
      }
    },

    async refreshConnectionState() {
      try {
        const response = await EvolutionAPI.getConnectionState(this.inboxId);
        this.connectionState = response.data;

        if (this.isConnected) {
          this.qrCode = null;
          this.stopPolling();
        }
      } catch (err) {
        console.error('Failed to get connection state:', err);
      }
    },

    async fetchQRCode() {
      this.isRefreshingQR = true;
      try {
        const response = await EvolutionAPI.getQRCode(this.inboxId);
        this.qrCode = response.data;
      } catch (err) {
        useAlert(
          err.response?.data?.error ||
            this.$t('INBOX_MGMT.ADD.EVOLUTION.CONNECT.QR_ERROR')
        );
      } finally {
        this.isRefreshingQR = false;
      }
    },

    async refreshQRCode() {
      await this.fetchQRCode();
    },

    startPolling() {
      if (this.pollTimer) return;
      this.pollTimer = setInterval(async () => {
        await this.refreshConnectionState();
        // If still not connected and QR expired, refresh it
        if (!this.isConnected && !this.qrCode?.base64) {
          await this.fetchQRCode();
        }
      }, POLL_INTERVAL);
    },

    stopPolling() {
      if (this.pollTimer) {
        clearInterval(this.pollTimer);
        this.pollTimer = null;
      }
    },

    async continueToAgents() {
      if (!this.isConnected) {
        useAlert(this.$t('INBOX_MGMT.ADD.EVOLUTION.CONNECT.NOT_CONNECTED'));
        return;
      }

      this.isEnablingIntegration = true;
      try {
        // Enable Chatwoot integration in Evolution
        await EvolutionAPI.enableIntegration(this.inboxId);

        useAlert(this.$t('INBOX_MGMT.ADD.EVOLUTION.CONNECT.INTEGRATION_ENABLED'));

        // Navigate to add agents
        this.$router.replace({
          name: 'settings_inboxes_add_agents',
          params: {
            page: 'new',
            inbox_id: this.inboxId,
          },
        });
      } catch (err) {
        useAlert(
          err.response?.data?.error ||
            this.$t('INBOX_MGMT.ADD.EVOLUTION.CONNECT.ENABLE_ERROR')
        );
      } finally {
        this.isEnablingIntegration = false;
      }
    },
  },
};
</script>

<template>
  <div class="mx-auto max-w-lg">
    <div v-if="isLoading" class="flex justify-center py-12">
      <Spinner size="large" />
    </div>

    <div v-else-if="error" class="text-center py-12">
      <div class="text-r-500 mb-4">
        {{ error }}
      </div>
      <NextButton
        :label="$t('INBOX_MGMT.ADD.EVOLUTION.CONNECT.RETRY')"
        @click="fetchInboxAndConnect"
      />
    </div>

    <div v-else class="flex flex-col gap-6">
      <!-- Header -->
      <div class="text-center">
        <h2 class="text-xl font-semibold text-n-slate-12">
          {{ $t('INBOX_MGMT.ADD.EVOLUTION.CONNECT.TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-11 mt-1">
          {{ $t('INBOX_MGMT.ADD.EVOLUTION.CONNECT.DESCRIPTION') }}
        </p>
      </div>

      <!-- Connection Status -->
      <div class="flex items-center justify-center gap-3 p-4 bg-n-alpha-1 rounded-lg">
        <span
          class="inline-block w-3 h-3 rounded-full"
          :class="statusColor"
        />
        <span class="text-sm font-medium text-n-slate-12">
          {{ statusLabel }}
        </span>
      </div>

      <!-- QR Code Display -->
      <div
        v-if="!isConnected"
        class="flex flex-col items-center gap-4 p-6 bg-white dark:bg-n-solid-3 rounded-xl border border-n-weak"
      >
        <div v-if="qrCode?.base64" class="flex flex-col items-center gap-4">
          <img
            :src="qrCode.base64"
            alt="QR Code"
            class="w-64 h-64 rounded-lg"
          />
          <p class="text-sm text-center text-n-slate-11">
            {{ $t('INBOX_MGMT.ADD.EVOLUTION.CONNECT.QR_INSTRUCTION') }}
          </p>
        </div>

        <div v-else class="flex flex-col items-center gap-4 py-8">
          <Spinner v-if="isRefreshingQR" />
          <p v-else class="text-sm text-n-slate-11">
            {{ $t('INBOX_MGMT.ADD.EVOLUTION.CONNECT.QR_LOADING') }}
          </p>
        </div>

        <NextButton
          ghost
          :label="$t('INBOX_MGMT.ADD.EVOLUTION.CONNECT.REFRESH_QR')"
          :is-loading="isRefreshingQR"
          @click="refreshQRCode"
        />
      </div>

      <!-- Connected State -->
      <div
        v-else
        class="flex flex-col items-center gap-4 p-6 bg-g-alpha-1 rounded-xl border border-g-200 dark:border-g-700"
      >
        <div class="text-g-500 text-5xl">✓</div>
        <p class="text-sm font-medium text-g-700 dark:text-g-300">
          {{ $t('INBOX_MGMT.ADD.EVOLUTION.CONNECT.CONNECTED') }}
        </p>
      </div>

      <!-- Continue Button -->
      <div class="flex justify-end">
        <NextButton
          :label="$t('INBOX_MGMT.ADD.EVOLUTION.CONNECT.CONTINUE')"
          :disabled="!isConnected"
          :is-loading="isEnablingIntegration"
          @click="continueToAgents"
        />
      </div>
    </div>
  </div>
</template>

