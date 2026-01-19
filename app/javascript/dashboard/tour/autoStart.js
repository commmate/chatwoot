/**
 * Tour auto-start integration
 *
 * Hooks into Vue Router to automatically start flows when users navigate
 * to specific routes. Uses the Flow Engine to determine which flow to run.
 */

import { maybeStartFlowForRoute, isFlowActive } from './flowEngine';
import { initializeFlows } from './flows';
import { isUserAdmin } from './permissions';
import { t as tourT } from './i18nHelper';

let flowStartPending = false;
let flowsInitialized = false;

/**
 * Get user permissions for account
 */
function getUserPermissionsForAccount(user, accountId) {
  if (!user?.accounts?.length) return [];
  const account = user.accounts.find(a => a.id === Number(accountId));
  if (!account) return [];
  if (account.role === 'administrator') return ['administrator'];
  return account.permissions || [];
}

/**
 * Check if user has any of the required permissions
 */
function hasPermissionsCheck(required, userPermissions) {
  if (!required?.length) return true;
  if (userPermissions.includes('administrator')) return true;
  return required.some(p => userPermissions.includes(p));
}

/**
 * Ensure the Vue i18n locale matches the user's preferred language
 * @param {Object} user - Current user object
 * @param {Object} store - Vuex store
 */
function ensureUserLocale(user, store) {
  try {
    const userLocale = user?.ui_settings?.locale;
    if (!userLocale) return;

    const appElement = document.querySelector('#app');
    // eslint-disable-next-line no-underscore-dangle
    if (appElement && appElement.__vue_app__) {
      // eslint-disable-next-line no-underscore-dangle
      const i18n = appElement.__vue_app__.config.globalProperties.$i18n;
      if (i18n && i18n.locale !== userLocale) {
        const accountId = store.getters.getCurrentAccountId;
        const account = store.getters['accounts/getAccount'](accountId);
        const accountLocale = account?.locale || 'en';
        const targetLocale = userLocale || accountLocale;

        if (i18n.availableLocales?.includes(targetLocale)) {
          i18n.locale = targetLocale;
        }
      }
    }
  } catch {
    // Silently fail if locale cannot be set
  }
}

/**
 * Build tour context from store state
 * @param {Object} store - Vuex store
 * @param {Object} router - Vue Router instance
 * @returns {Object} Tour context
 */
function buildTourContext(store, router) {
  const user = store.getters.getCurrentUser;
  const accountId = store.getters.getCurrentAccountId;
  const uiSettings = user?.ui_settings || {};
  const inboxes = store.getters['inboxes/getInboxes'] || [];
  const isAdmin = isUserAdmin(user, accountId);

  const hasWhatsAppCloud = inboxes.some(
    inbox =>
      inbox.channel_type === 'Channel::Whatsapp' &&
      inbox.provider === 'whatsapp_cloud'
  );

  const appIntegrations =
    store.getters['integrations/getAppIntegrations'] || [];
  const isAIEnabled = appIntegrations.some(
    integration => integration.id === 'openai' && integration.hooks?.length > 0
  );

  const checkPermissions = requiredPermissions => {
    if (!requiredPermissions?.length) return true;
    const userPermissions = getUserPermissionsForAccount(user, accountId);
    return hasPermissionsCheck(requiredPermissions, userPermissions);
  };

  const isFeatureEnabled = featureFlag => {
    if (!featureFlag) return true;
    return store.getters['accounts/isFeatureEnabledonAccount'](
      accountId,
      featureFlag
    );
  };

  const updateUISettings = async payload => {
    await store.dispatch('updateUISettings', { uiSettings: payload });
  };

  const navigateTo = async route => {
    await router.push(route);
  };

  return {
    user,
    accountId,
    uiSettings,
    isAdmin,
    inboxes,
    hasWhatsAppCloud,
    isAIEnabled,
    checkPermissions,
    isFeatureEnabled,
    updateUISettings,
    navigateTo,
    t: tourT,
  };
}

/**
 * Initialize tour auto-start with router afterEach hook
 * @param {Object} router - Vue Router instance
 * @param {Object} store - Vuex store
 */
export function initializeTourAutoStart(router, store) {
  if (!flowsInitialized) {
    initializeFlows();
    flowsInitialized = true;
  }

  router.afterEach(async to => {
    // Debounce check
    if (flowStartPending || isFlowActive()) return;

    // Ensure user is logged in
    const user = store.getters.getCurrentUser;
    if (!user?.id) return;

    const accountId = store.getters.getCurrentAccountId;
    if (!accountId) return;

    try {
      flowStartPending = true;
      ensureUserLocale(user, store);
      const context = buildTourContext(store, router);
      await maybeStartFlowForRoute(to, context);
    } finally {
      setTimeout(() => {
        flowStartPending = false;
      }, 2000);
    }
  });
}
