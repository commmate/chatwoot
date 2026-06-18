<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import ChannelSelector from '../ChannelSelector.vue';

const props = defineProps({
  channel: {
    type: Object,
    required: true,
  },
  enabledFeatures: {
    type: Object,
    required: true,
  },
  evolutionHealth: {
    type: Object,
    default: () => ({ healthy: false, checked: false }),
  },
});

const emit = defineEmits(['channelItemClick']);

const { t } = useI18n();

const hasFbConfigured = computed(() => {
  return window.chatwootConfig?.fbAppId;
});

const hasInstagramConfigured = computed(() => {
  return window.chatwootConfig?.instagramAppId;
});

const hasTiktokConfigured = computed(() => {
  return window.chatwootConfig?.tiktokAppId;
});

const hasEvolutionConfigured = computed(() => {
  return window.chatwootConfig?.evolutionApiEnabled === 'true';
});

const isActive = computed(() => {
  const { key } = props.channel;
  if (Object.keys(props.enabledFeatures).length === 0) {
    return false;
  }
  if (key === 'website') {
    return props.enabledFeatures.channel_website;
  }
  if (key === 'facebook') {
    return props.enabledFeatures.channel_facebook && hasFbConfigured.value;
  }
  if (key === 'email') {
    return props.enabledFeatures.channel_email;
  }

  if (key === 'instagram') {
    return (
      props.enabledFeatures.channel_instagram && hasInstagramConfigured.value
    );
  }

  if (key === 'tiktok') {
    return props.enabledFeatures.channel_tiktok && hasTiktokConfigured.value;
  }

  if (key === 'voice') {
    return props.enabledFeatures.channel_voice;
  }

  if (key === 'evolution') {
    return (
      hasEvolutionConfigured.value &&
      props.evolutionHealth.checked &&
      props.evolutionHealth.healthy
    );
  }

  if (key === 'whatsapp_call') {
    return (
      props.enabledFeatures.channel_voice &&
      !!window.chatwootConfig?.whatsappAppId &&
      window.chatwootConfig.whatsappAppId !== 'none'
    );
  }

  return [
    'website',
    'twilio',
    'api',
    'whatsapp',
    'sms',
    'telegram',
    'line',
    'instagram',
    'tiktok',
    'voice',
  ].includes(key);
});

const isComingSoon = computed(() => {
  const { key } = props.channel;
  // Show "Coming Soon" only if the channel is marked as coming soon
  // and the corresponding feature flag is not enabled yet.
  return ['voice'].includes(key) && !isActive.value;
});

const isUnavailable = computed(() => {
  const { key } = props.channel;
  if (key === 'evolution') {
    return (
      hasEvolutionConfigured.value &&
      props.evolutionHealth.checked &&
      !props.evolutionHealth.healthy
    );
  }
  return false;
});

const channelDescription = computed(() => {
  if (isUnavailable.value) {
    return t('INBOX_MGMT.ADD.AUTH.CHANNEL.EVOLUTION.UNAVAILABLE');
  }
  return props.channel.description;
});

const isBeta = computed(() => {
  return ['tiktok', 'voice', 'whatsapp_call'].includes(props.channel.key);
});

const hasVoiceBadge = computed(() => {
  return (
    ['voice', 'whatsapp_call'].includes(props.channel.key) &&
    !!props.enabledFeatures.channel_voice
  );
});

const onItemClick = () => {
  if (isActive.value) {
    emit('channelItemClick', props.channel.key);
  }
};
</script>

<template>
  <ChannelSelector
    :title="channel.title"
    :description="channelDescription"
    :icon="channel.icon"
    :is-coming-soon="isComingSoon"
    :is-unavailable="isUnavailable"
    :is-beta="isBeta"
    :has-voice-badge="hasVoiceBadge"
    :disabled="!isActive"
    @click="onItemClick"
  />
</template>
