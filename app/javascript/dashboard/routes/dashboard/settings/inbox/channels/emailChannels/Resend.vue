<script>
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required, email } from '@vuelidate/validators';
import router from '../../../../../index';
import PageHeader from '../../../SettingsSubPageHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    PageHeader,
    NextButton,
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      channelName: '',
      fromEmail: '',
      fromName: '',
      apiKey: '',
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'inboxes/getUIFlags',
    }),
  },
  validations: {
    channelName: { required },
    fromEmail: { required, email },
    apiKey: { required },
  },
  methods: {
    async createChannel() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }

      try {
        const emailChannel = await this.$store.dispatch(
          'inboxes/createChannel',
          {
            name: this.channelName?.trim(),
            channel: {
              type: 'email',
              email: this.fromEmail,
              provider: 'resend',
              provider_config: {
                api_key: this.apiKey,
                from_email: this.fromEmail,
                from_name: this.fromName || this.channelName,
              },
            },
          }
        );

        router.replace({
          name: 'settings_inboxes_add_agents',
          params: {
            page: 'new',
            inbox_id: emailChannel.id,
          },
        });
      } catch (error) {
        const errorMessage = error?.message;
        useAlert(
          errorMessage || this.$t('INBOX_MGMT.ADD.RESEND.API.ERROR_MESSAGE')
        );
      }
    },
  },
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.RESEND.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.RESEND.DESC')"
    />
    <form
      class="flex flex-wrap flex-col mx-0 max-w-lg"
      @submit.prevent="createChannel()"
    >
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

      <div class="flex-shrink-0 flex-grow-0 mb-4">
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
            {{ $t('INBOX_MGMT.ADD.RESEND.API_KEY.ERROR') }}
          </span>
        </label>
      </div>

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
            {{ $t('INBOX_MGMT.ADD.RESEND.FROM_EMAIL.SUBTITLE') }}
          </p>
          <span v-if="v$.fromEmail.$error" class="message">
            {{ $t('INBOX_MGMT.ADD.RESEND.FROM_EMAIL.ERROR') }}
          </span>
        </label>
      </div>

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
          :is-loading="uiFlags.isCreating"
          type="submit"
          solid
          blue
          :label="$t('INBOX_MGMT.ADD.RESEND.SUBMIT_BUTTON')"
        />
      </div>
    </form>
  </div>
</template>
