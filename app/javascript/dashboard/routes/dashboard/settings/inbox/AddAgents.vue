<script>
/* eslint no-console: 0 */
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';

import InboxMembersAPI from '../../../../api/inboxMembers';
import EvolutionAPI from 'dashboard/api/evolution';
import NextButton from 'dashboard/components-next/button/Button.vue';
import router from '../../../index';
import PageHeader from '../SettingsSubPageHeader.vue';
import { useVuelidate } from '@vuelidate/core';

export default {
  components: {
    PageHeader,
    NextButton,
  },
  validations: {
    selectedAgents: {
      isEmpty() {
        return !!this.selectedAgents.length;
      },
    },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      selectedAgents: [],
      isCreating: false,
    };
  },
  computed: {
    ...mapGetters({
      agentList: 'agents/getAgents',
    }),
  },
  mounted() {
    this.$store.dispatch('agents/get');
    this.checkEvolutionBaileysConnection();
  },
  methods: {
    async checkEvolutionBaileysConnection() {
      // Only check during new inbox flow (not when editing)
      if (this.$route.params.page !== 'new') {
        return;
      }

      const inboxId = this.$route.params.inbox_id;
      if (!inboxId) return;

      try {
        // Fetch inbox to check if it's Evolution Baileys
        await this.$store.dispatch('inboxes/get', inboxId);
        const inbox = this.$store.getters['inboxes/getInbox'](inboxId);

        if (!inbox) return;

        const isEvolutionBaileys =
          inbox.channel_type === 'Channel::Api' &&
          inbox.additional_attributes?.evolution_channel === 'baileys';

        if (!isEvolutionBaileys) return;

        // Check if WhatsApp is connected
        const connectionResponse = await EvolutionAPI.getConnectionState(
          inboxId
        );
        const isConnected =
          connectionResponse.data?.instance?.state === 'open';

        if (!isConnected) {
          // Redirect back to connect step
          useAlert(
            this.$t('INBOX_MGMT.ADD.EVOLUTION.CONNECT.NOT_CONNECTED')
          );
          router.replace({
            name: 'settings_inboxes_evolution_connect',
            params: {
              page: 'new',
              inbox_id: inboxId,
            },
          });
        }
      } catch (error) {
        // If we can't check, don't block - just log and continue
        console.error('Failed to check Evolution connection:', error);
      }
    },
    async addAgents() {
      this.isCreating = true;
      const inboxId = this.$route.params.inbox_id;
      const selectedAgents = this.selectedAgents.map(x => x.id);

      try {
        await InboxMembersAPI.update({ inboxId, agentList: selectedAgents });
        router.replace({
          name: 'settings_inbox_finish',
          params: {
            page: 'new',
            inbox_id: this.$route.params.inbox_id,
          },
        });
      } catch (error) {
        useAlert(error.message);
      }
      this.isCreating = false;
    },
  },
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <form class="flex flex-wrap flex-col mx-0" @submit.prevent="addAgents()">
      <div class="w-full">
        <PageHeader
          :header-title="$t('INBOX_MGMT.ADD.AGENTS.TITLE')"
          :header-content="$t('INBOX_MGMT.ADD.AGENTS.DESC')"
        />
      </div>
      <div>
        <div class="w-full">
          <label :class="{ error: v$.selectedAgents.$error }">
            {{ $t('INBOX_MGMT.ADD.AGENTS.TITLE') }}
            <multiselect
              v-model="selectedAgents"
              :options="agentList"
              track-by="id"
              label="name"
              multiple
              :close-on-select="false"
              :clear-on-select="false"
              hide-selected
              selected-label
              :select-label="$t('FORMS.MULTISELECT.ENTER_TO_SELECT')"
              :deselect-label="$t('FORMS.MULTISELECT.ENTER_TO_REMOVE')"
              :placeholder="$t('INBOX_MGMT.ADD.AGENTS.PICK_AGENTS')"
              @select="v$.selectedAgents.$touch"
            />
            <span v-if="v$.selectedAgents.$error" class="message">
              {{ $t('INBOX_MGMT.ADD.AGENTS.VALIDATION_ERROR') }}
            </span>
          </label>
        </div>
        <div class="w-full">
          <NextButton
            type="submit"
            :is-loading="isCreating"
            solid
            blue
            :label="$t('INBOX_MGMT.AGENTS.BUTTON_TEXT')"
          />
        </div>
      </div>
    </form>
  </div>
</template>
