/**
 * i18n Helper for Tour Module
 *
 * Provides access to translations outside of Vue components.
 * This is needed because the tour engine runs in router hooks, not Vue component context.
 */

/**
 * Translation function for use in tour module
 * Gets translations from the global Vue app's $t function
 * @param {string} key - i18n key (e.g., 'TOUR.BUTTONS.NEXT')
 * @returns {string} Translated string or key if not found
 */
export function t(key) {
  try {
    const appElement = document.querySelector('#app');
    // eslint-disable-next-line no-underscore-dangle
    if (appElement && appElement.__vue_app__) {
      // eslint-disable-next-line no-underscore-dangle
      const $t = appElement.__vue_app__.config.globalProperties.$t;
      if ($t) {
        const translated = $t(key);
        return translated !== key ? translated : key;
      }
    }
  } catch {
    // Fallback to key if anything fails
  }
  return key;
}
