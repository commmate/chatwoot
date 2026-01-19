/**
 * Tour wait utilities
 *
 * Helpers for waiting on DOM elements and route readiness.
 */

/**
 * Wait for an element to exist in DOM
 * @param {string} selector - CSS selector
 * @param {number} timeout - Max wait time in ms
 * @returns {Promise<Element|null>}
 */
export function waitForElement(selector, timeout = 3000) {
  return new Promise(resolve => {
    const existing = document.querySelector(selector);
    if (existing) {
      resolve(existing);
      return;
    }

    const observer = new MutationObserver(() => {
      const element = document.querySelector(selector);
      if (element) {
        observer.disconnect();
        resolve(element);
      }
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true,
    });

    setTimeout(() => {
      observer.disconnect();
      resolve(null);
    }, timeout);
  });
}

/**
 * Wait for multiple elements (returns when all found or timeout)
 * @param {string[]} selectors - Array of CSS selectors
 * @param {number} timeout - Max wait time in ms
 * @returns {Promise<Object>} Map of selector -> element (null if not found)
 */
export async function waitForElements(selectors, timeout = 3000) {
  const results = {};
  const promises = selectors.map(async selector => {
    results[selector] = await waitForElement(selector, timeout);
  });
  await Promise.all(promises);
  return results;
}

/**
 * Simple delay promise
 * @param {number} ms - Milliseconds to wait
 * @returns {Promise<void>}
 */
export function delay(ms) {
  return new Promise(resolve => {
    setTimeout(resolve, ms);
  });
}

/**
 * Wait for Vue/DOM to settle after navigation
 * @param {number} ms - Milliseconds to wait (default 500)
 * @returns {Promise<void>}
 */
export function waitForRouteReady(ms = 500) {
  return delay(ms);
}

/**
 * Try to find element, retry a few times with delays
 * @param {string} selector - CSS selector
 * @param {number} retries - Number of retries
 * @param {number} delayMs - Delay between retries
 * @returns {Promise<Element|null>}
 */
export async function findElementWithRetry(
  selector,
  retries = 3,
  delayMs = 300
) {
  for (let i = 0; i < retries; i += 1) {
    const element = document.querySelector(selector);
    if (element) return element;
    if (i < retries - 1) {
      // eslint-disable-next-line no-await-in-loop
      await delay(delayMs);
    }
  }
  return null;
}
