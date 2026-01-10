import { INBOX_TYPES } from 'dashboard/helper/inbox';

export const INBOX_FEATURES = {
  REPLY_TO: 'replyTo',
  REPLY_TO_OUTGOING: 'replyToOutgoing',
};

// This is a single source of truth for inbox features
// This is used to check if a feature is available for a particular inbox or not
export const INBOX_FEATURE_MAP = {
  [INBOX_FEATURES.REPLY_TO]: [
    INBOX_TYPES.FB,
    INBOX_TYPES.WEB,
    INBOX_TYPES.TWITTER,
    INBOX_TYPES.WHATSAPP,
    INBOX_TYPES.TELEGRAM,
    INBOX_TYPES.TIKTOK,
    INBOX_TYPES.API,
  ],
  [INBOX_FEATURES.REPLY_TO_OUTGOING]: [
    INBOX_TYPES.WEB,
    INBOX_TYPES.TWITTER,
    INBOX_TYPES.WHATSAPP,
    INBOX_TYPES.TELEGRAM,
    INBOX_TYPES.TIKTOK,
    INBOX_TYPES.API,
  ],
};

export default {
  computed: {
    channelType() {
      return this.inbox.channel_type;
    },
    whatsAppAPIProvider() {
      return this.inbox.provider || '';
    },
    isAMicrosoftInbox() {
      return this.isAnEmailChannel && this.inbox.provider === 'microsoft';
    },
    isAGoogleInbox() {
      return this.isAnEmailChannel && this.inbox.provider === 'google';
    },
    isAPIInbox() {
      return this.channelType === INBOX_TYPES.API;
    },
    isATwitterInbox() {
      return this.channelType === INBOX_TYPES.TWITTER;
    },
    isAFacebookInbox() {
      return this.channelType === INBOX_TYPES.FB;
    },
    isAWebWidgetInbox() {
      return this.channelType === INBOX_TYPES.WEB;
    },
    isATwilioChannel() {
      return this.channelType === INBOX_TYPES.TWILIO;
    },
    isALineChannel() {
      return this.channelType === INBOX_TYPES.LINE;
    },
    isAVoiceChannel() {
      return this.channelType === INBOX_TYPES.VOICE;
    },
    isAnEmailChannel() {
      return this.channelType === INBOX_TYPES.EMAIL;
    },
    isATelegramChannel() {
      return this.channelType === INBOX_TYPES.TELEGRAM;
    },
    isATwilioSMSChannel() {
      const { medium: medium = '' } = this.inbox;
      return this.isATwilioChannel && medium === 'sms';
    },
    isASmsInbox() {
      return this.channelType === INBOX_TYPES.SMS || this.isATwilioSMSChannel;
    },
    isATwilioWhatsAppChannel() {
      const { medium: medium = '' } = this.inbox;
      return this.isATwilioChannel && medium === 'whatsapp';
    },
    // Check if inbox is an Evolution Cloud WhatsApp API inbox
    isEvolutionCloudWhatsApp() {
      if (this.channelType !== INBOX_TYPES.API) return false;
      const { additional_attributes: additionalAttributes = {} } = this.inbox;
      return additionalAttributes?.evolution_channel === 'whatsapp_cloud_api';
    },
    // Check if inbox is an Evolution Baileys inbox
    isEvolutionBaileys() {
      if (this.channelType !== INBOX_TYPES.API) return false;
      const { additional_attributes: additionalAttributes = {} } = this.inbox;
      return additionalAttributes?.evolution_channel === 'baileys';
    },
    // Check if inbox is any Evolution API inbox (Cloud or Baileys)
    isEvolutionApiInbox() {
      if (this.channelType !== INBOX_TYPES.API) return false;
      const { additional_attributes: additionalAttributes = {} } = this.inbox;
      return !!additionalAttributes?.evolution_instance_name;
    },
    isAWhatsAppCloudChannel() {
      // Native WhatsApp Cloud
      const isNativeCloud =
        this.channelType === INBOX_TYPES.WHATSAPP &&
        this.whatsAppAPIProvider === 'whatsapp_cloud';
      // Evolution Cloud API should also be treated as WhatsApp Cloud
      return isNativeCloud || this.isEvolutionCloudWhatsApp;
    },
    is360DialogWhatsAppChannel() {
      return (
        this.channelType === INBOX_TYPES.WHATSAPP &&
        this.whatsAppAPIProvider === 'default'
      );
    },
    chatAdditionalAttributes() {
      const { additional_attributes: additionalAttributes } = this.chat || {};
      return additionalAttributes || {};
    },
    isTwitterInboxTweet() {
      return this.chatAdditionalAttributes.type === 'tweet';
    },
    twilioBadge() {
      return `${this.isATwilioSMSChannel ? 'sms' : 'whatsapp'}`;
    },
    twitterBadge() {
      return `${this.isTwitterInboxTweet ? 'twitter-tweet' : 'twitter-dm'}`;
    },
    facebookBadge() {
      return this.chatAdditionalAttributes.type || 'facebook';
    },
    inboxBadge() {
      let badgeKey = '';
      if (this.isATwitterInbox) {
        badgeKey = this.twitterBadge;
      } else if (this.isAFacebookInbox) {
        badgeKey = this.facebookBadge;
      } else if (this.isATwilioChannel) {
        badgeKey = this.twilioBadge;
      } else if (this.isAWhatsAppChannel) {
        badgeKey = 'whatsapp';
      } else if (this.isATiktokChannel) {
        badgeKey = 'tiktok';
      }
      return badgeKey || this.channelType;
    },
    isAWhatsAppChannel() {
      return (
        this.channelType === INBOX_TYPES.WHATSAPP ||
        this.isATwilioWhatsAppChannel ||
        this.isEvolutionCloudWhatsApp
      );
    },
    isAnInstagramChannel() {
      return this.channelType === INBOX_TYPES.INSTAGRAM;
    },
    isATiktokChannel() {
      return this.channelType === INBOX_TYPES.TIKTOK;
    },
  },
  methods: {
    inboxHasFeature(feature) {
      return INBOX_FEATURE_MAP[feature]?.includes(this.channelType) ?? false;
    },
  },
};
