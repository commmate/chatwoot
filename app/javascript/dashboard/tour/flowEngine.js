/**
 * Flow Engine
 *
 * Orchestrates modular tour flows based on route, user role, and completion state.
 * Only one flow runs at a time. Flows are route-scoped and support skip/completion.
 * Mobile-friendly with responsive positioning and touch-optimized UI.
 */

import { driver } from 'driver.js';
import 'driver.js/dist/driver.css';

import { delay } from './waitFor';
import { filterStepsByPermissions } from './permissions';
import {
  isFlowCompleted,
  isFlowSkipped,
  markFlowComplete,
  markFlowSkipped,
} from './state';

// Global driver instance (only one flow at a time)
let activeDriver = null;
let activeFlowId = null;

// Flow registry - populated by registerFlow()
const flowRegistry = new Map();

// Mobile detection
const MOBILE_BREAKPOINT = 768;
const MOBILE_SIDEBAR_LAUNCHER_SELECTOR = '#mobile-sidebar-launcher button';
const MOBILE_SIDEBAR_SELECTOR = 'aside';
const SIDEBAR_SETTINGS_SELECTOR = '[data-tour="sidebar-settings"]';
const INTERACTION_SHIELD_ID = 'commmate-tour-interaction-shield';

/**
 * Check if current viewport is mobile-sized
 * @returns {boolean}
 */
function isMobileViewport() {
  return window.innerWidth < MOBILE_BREAKPOINT;
}

/**
 * Inject mobile-friendly CSS styles for the tour
 */
function injectMobileStyles() {
  const styleId = 'commmate-tour-mobile-styles';
  if (document.getElementById(styleId)) return;

  const style = document.createElement('style');
  style.id = styleId;
  style.textContent = `
    /* Mobile-friendly tour styles */
    .commmate-tour.driver-popover {
      max-width: calc(100vw - 32px) !important;
      margin: 0 16px;
    }

    @media (max-width: ${MOBILE_BREAKPOINT}px) {
      .commmate-tour.driver-popover {
        max-width: calc(100vw - 24px) !important;
        margin: 0 12px;
        font-size: 14px;
      }

      .commmate-tour .driver-popover-title {
        font-size: 16px;
        line-height: 1.3;
      }

      .commmate-tour .driver-popover-description {
        font-size: 14px;
        line-height: 1.5;
      }

      /* Larger touch targets for buttons */
      .commmate-tour .driver-popover-footer button,
      .commmate-tour .driver-popover-navigation-btns button {
        min-height: 44px;
        min-width: 44px;
        padding: 10px 16px;
        font-size: 14px;
      }

      /* Stack buttons vertically on very small screens */
      @media (max-width: 380px) {
        .commmate-tour .driver-popover-footer {
          flex-direction: column;
          gap: 8px;
        }

        .commmate-tour .driver-popover-navigation-btns {
          width: 100%;
          justify-content: space-between;
        }

        .commmate-tour .driver-popover-navigation-btns button {
          flex: 1;
        }
      }

      /* Adjust progress text */
      .commmate-tour .driver-popover-progress-text {
        font-size: 12px;
      }

      /* Skip button mobile styling */
      .driver-popover-skip-btn {
        min-height: 44px;
        padding: 10px 16px !important;
      }

      /* Navigate button mobile styling */
      .driver-popover-navigate-btn {
        min-height: 44px;
        padding: 10px 16px !important;
      }
    }

    /* Ensure popover doesn't overflow screen */
    .commmate-tour.driver-popover {
      box-sizing: border-box;
    }

    /* Ensure the tour overlay sits above any dropdown portals/modals */
    .driver-overlay {
      z-index: 100000 !important;
    }

    .commmate-tour.driver-popover {
      z-index: 100001 !important;
    }

    /* Shield blocks clicks on the app while tour is running */
    #${INTERACTION_SHIELD_ID} {
      position: fixed;
      inset: 0;
      z-index: 99999;
      pointer-events: auto;
      background: transparent;
    }

    /* Better contrast for accessibility */
    .commmate-tour .driver-popover-description {
      color: inherit;
      opacity: 0.9;
    }
  `;
  document.head.appendChild(style);
}

function ensureInteractionShield() {
  if (document.getElementById(INTERACTION_SHIELD_ID)) return;
  const shield = document.createElement('div');
  shield.id = INTERACTION_SHIELD_ID;

  // Capture and stop all pointer events so app doesn't react.
  const stop = e => {
    e.preventDefault();
    e.stopPropagation();
  };
  [
    'click',
    'mousedown',
    'mouseup',
    'pointerdown',
    'pointerup',
    'touchstart',
    'touchend',
  ].forEach(evt => shield.addEventListener(evt, stop, { passive: false }));

  document.body.appendChild(shield);
}

function removeInteractionShield() {
  const shield = document.getElementById(INTERACTION_SHIELD_ID);
  shield?.remove?.();
}

function elementVisible(el) {
  if (!el) return false;
  const style = window.getComputedStyle(el);
  if (style.display === 'none' || style.visibility === 'hidden') return false;
  return true;
}

async function waitForVisibleElement(selector, timeout = 3000) {
  const start = Date.now();
  while (Date.now() - start < timeout) {
    const el = document.querySelector(selector);
    if (el && elementVisible(el)) return el;
    // eslint-disable-next-line no-await-in-loop
    await delay(50);
  }
  return null;
}

function isMobileSidebarOpen() {
  const aside = document.querySelector(MOBILE_SIDEBAR_SELECTOR);
  if (!aside) return false;

  // Sidebar.vue toggles these classes when closed on mobile
  return (
    !aside.classList.contains('ltr:-translate-x-full') &&
    !aside.classList.contains('rtl:translate-x-full')
  );
}

async function ensureMobileSidebarOpen() {
  if (!isMobileViewport()) return;
  if (isMobileSidebarOpen()) return;

  const launcher = document.querySelector(MOBILE_SIDEBAR_LAUNCHER_SELECTOR);
  if (!launcher) return;

  launcher.click();
  await delay(250);

  // Best-effort: wait until the sidebar is open (or time out)
  for (let i = 0; i < 8; i += 1) {
    if (isMobileSidebarOpen()) return;
    // eslint-disable-next-line no-await-in-loop
    await delay(100);
  }
}

function expandSettingsViaStorage() {
  try {
    const key = 'next-sidebar-expanded-item';
    const value = JSON.stringify('Settings');
    sessionStorage.setItem(key, value);

    // vueuse/useStorage listens for storage events; dispatch one for same-tab updates.
    window.dispatchEvent(
      new StorageEvent('storage', {
        key,
        newValue: value,
        oldValue: null,
        storageArea: sessionStorage,
        url: window.location.href,
      })
    );
  } catch (e) {
    // eslint-disable-next-line no-console
    console.warn('[Tour] Failed to expand Settings via storage', e);
  }
}

async function ensureSettingsExpanded() {
  // Try storage approach first (works for desktop, sometimes mobile)
  expandSettingsViaStorage();
  await delay(150);

  // Check if a Settings child is already visible (means group is expanded)
  const teamsLink = document.querySelector('[data-tour="settings-teams"]');
  if (teamsLink && elementVisible(teamsLink) && teamsLink.offsetWidth > 0) {
    return; // Already expanded
  }

  // Fallback: click the Settings header to expand.
  // This is safe because SidebarGroup.toggleTrigger does NOT navigate when
  // clicking just expands/collapses the group.
  const settingsHeader = document.querySelector(SIDEBAR_SETTINGS_SELECTOR);
  if (settingsHeader && elementVisible(settingsHeader)) {
    settingsHeader.click();
    await delay(250); // Give more time for expand animation

    // Double-check if it expanded
    const teamsAfterClick = document.querySelector(
      '[data-tour="settings-teams"]'
    );
    if (teamsAfterClick && teamsAfterClick.offsetWidth > 0) {
      return; // Success
    }

    // Last resort: try clicking again (sometimes first click navigates to settings)
    settingsHeader.click();
    await delay(250);
  }
}

function selectorNeedsSidebar(selector) {
  if (!selector || typeof selector !== 'string') return false;
  return (
    selector.includes('sidebar-') ||
    selector.includes('aside ') ||
    selector.includes('/settings/') ||
    selector.includes('data-tour="settings-')
  );
}

function selectorNeedsSettingsExpanded(selector) {
  if (!selector || typeof selector !== 'string') return false;
  // Settings leaf items only render when Settings group is expanded or a child is active.
  // Also match data-tour="settings-*" selectors (new stable hooks)
  return (
    selector.includes('/settings/') || selector.includes('data-tour="settings-')
  );
}

async function waitForUrlIncludes(partial, timeout = 5000) {
  if (!partial) return true;
  const start = Date.now();
  while (Date.now() - start < timeout) {
    if (window.location.pathname.includes(partial)) return true;
    // eslint-disable-next-line no-await-in-loop
    await delay(50);
  }
  return false;
}

/**
 * Register a flow definition
 * @param {Object} flow - Flow definition object
 */
export function registerFlow(flow) {
  if (!flow.id) {
    throw new Error('Flow must have an id');
  }
  flowRegistry.set(flow.id, flow);
}

/**
 * Get all registered flows
 * @returns {Map}
 */
export function getFlowRegistry() {
  return flowRegistry;
}

/**
 * Check if a flow matches the current route
 * @param {Object} flow - Flow definition
 * @param {Object} route - Vue Router route object
 * @returns {boolean}
 */
function flowMatchesRoute(flow, route) {
  if (!flow.routes?.length) return false;

  return flow.routes.some(matcher => {
    // Simple name match
    if (typeof matcher === 'string') {
      return route.name === matcher;
    }

    // Object matcher with name and optional params
    if (typeof matcher === 'object') {
      if (matcher.name && route.name !== matcher.name) {
        return false;
      }

      // Check params if specified
      if (matcher.params) {
        const paramsMatch = Object.entries(matcher.params).every(
          ([key, value]) => route.params?.[key] === value
        );
        if (!paramsMatch) return false;
      }

      return true;
    }

    return false;
  });
}

/**
 * Find the appropriate flow for the current context
 * @param {Object} route - Vue Router route object
 * @param {Object} context - Tour context (user, accountId, uiSettings, etc.)
 * @returns {Object|null} Flow definition or null
 */
export function findFlowForRoute(route, context) {
  const { accountId, uiSettings } = context;

  const flows = Array.from(flowRegistry.values());
  return (
    flows.find(flow => {
      // Check route match
      if (!flowMatchesRoute(flow, route)) return false;

      // Check role match
      if (flow.role === 'admin' && !context.isAdmin) return false;
      if (flow.role === 'agent' && context.isAdmin) return false;

      // Check if already completed or skipped
      if (isFlowCompleted(uiSettings, accountId, flow.id)) return false;
      if (isFlowSkipped(uiSettings, accountId, flow.id)) return false;

      // Check prerequisites
      if (flow.prerequisites && typeof flow.prerequisites === 'function') {
        if (!flow.prerequisites(context)) return false;
      }

      return true;
    }) || null
  );
}

/**
 * Get mobile-friendly popover side
 * On mobile, avoid left/right positioning as it can cause overflow
 * @param {string} desiredSide - Desired popover side
 * @returns {string} Mobile-friendly side
 */
function getMobileFriendlySide(desiredSide) {
  if (!isMobileViewport()) {
    return desiredSide;
  }

  // On mobile, convert left/right to bottom/top
  switch (desiredSide) {
    case 'left':
    case 'right':
      return 'bottom';
    default:
      return desiredSide;
  }
}

/**
 * Resolve i18n key to translated string
 * @param {Function} t - Translation function from useI18n
 * @param {string} key - i18n key (e.g., 'TOUR.BUTTONS.SKIP')
 * @param {string} fallback - Fallback text if key not found
 * @returns {string}
 */
function resolveI18n(t, key, fallback = '') {
  if (!key) return fallback;
  if (!t) return fallback || key;
  try {
    const translated = t(key);
    // If translation returns the key itself, use fallback
    return translated === key ? fallback || key : translated;
  } catch {
    return fallback || key;
  }
}

/**
 * Transform step definition to driver.js format
 * @param {Object} step - Our step definition
 * @param {Object} context - Tour context
 * @param {Object} flow - Parent flow definition
 * @param {Object} driverRef - Reference wrapper { current: driver.js instance }
 * @returns {Object}
 */
function transformStep(step, context, flow, driverRef) {
  const { t } = context;
  const desiredSide = step.popover?.side || 'bottom';
  const mobileSide =
    step.popover?.mobileSide || getMobileFriendlySide(desiredSide);

  // Resolve i18n keys for title and description
  const title = step.popover?.titleKey
    ? resolveI18n(t, step.popover.titleKey)
    : step.popover?.title || '';
  const description = step.popover?.descriptionKey
    ? resolveI18n(t, step.popover.descriptionKey)
    : step.popover?.description || '';

  const driverStep = {
    popover: {
      title,
      description,
      side: isMobileViewport() ? mobileSide : desiredSide,
      align: step.popover?.align || 'start',
    },
  };

  if (step.element) {
    driverStep.element = step.element;
  }

  // Custom metadata for CommMate tour engine (used to sync navigation)
  /* eslint-disable no-underscore-dangle */
  if (step.waitForUrlIncludes) {
    driverStep._commmateWaitForUrlIncludes = step.waitForUrlIncludes;
  }
  if (step.waitForUrlTimeout) {
    driverStep._commmateWaitForUrlTimeout = step.waitForUrlTimeout;
  }
  /* eslint-enable no-underscore-dangle */

  // Always lock interaction with the highlighted element while tour is running.
  // (User requested: no clicking anywhere in the app during tour.)
  if (step.element) {
    driverStep.disableActiveInteraction = true;
  }

  // Ensure mobile sidebar is open when targeting sidebar/menu selectors.
  // Ensure Settings group is expanded before leaf items.
  // On desktop, navigate to specified route before highlighting (if configured).
  driverStep.onHighlightStarted = async (element, stepObj, options) => {
    const selector =
      typeof step.element === 'string' ? step.element : undefined;
    const needsSidebar = selectorNeedsSidebar(selector);
    const needsSettings = selectorNeedsSettingsExpanded(selector);
    const isMobile = isMobileViewport();

    // Desktop only: navigate to specified route before highlighting this step
    if (
      !isMobile &&
      step.navigateBeforeHighlightDesktop &&
      context.navigateTo
    ) {
      try {
        await context.navigateTo({
          ...step.navigateBeforeHighlightDesktop,
          params: {
            accountId: context.accountId,
            ...step.navigateBeforeHighlightDesktop.params,
          },
        });
        await delay(300); // Wait for page to render
      } catch (e) {
        // eslint-disable-next-line no-console
        console.warn('[Tour] Failed to navigate before highlight', e);
      }
    }

    // On mobile, re-open sidebar and re-expand settings on EVERY step that needs them
    // (the sidebar can close if user taps elsewhere or browser re-layouts).
    if (needsSidebar) {
      await ensureMobileSidebarOpen();
      // Give DOM time to render the opened sidebar
      await delay(150);
    }

    if (needsSettings) {
      await ensureSettingsExpanded();
      // Give DOM time to render the expanded settings group
      await delay(150);
    }

    // Now verify the element is visible; if not, wait a bit more
    if (selector && needsSidebar) {
      const el = await waitForVisibleElement(selector, 2000);
      if (!el) {
        // eslint-disable-next-line no-console
        console.warn(
          `[Tour] Element ${selector} not visible after sidebar/settings expansion`
        );
      }
    }

    if (step.onHighlightStarted) {
      step.onHighlightStarted(element, stepObj, {
        ...options,
        context,
        flow,
        driverRef,
      });
    }
  };

  // Add step-level hooks
  // Auto-navigation helper (used by main tours on desktop): click the highlighted
  // element for the NEXT step and then move to the next tour step.
  if (step.autoNavigateOnNext) {
    driverStep.popover.onNextClick = async (element, stepObj, options) => {
      const isMobile = isMobileViewport();
      const nextIndex = (options?.state?.activeIndex ?? 0) + 1;
      const nextStep = options?.config?.steps?.[nextIndex];

      // Desktop only: click the next step's sidebar item before advancing,
      // so the page matches the tooltip when it appears.
      if (!isMobile && nextStep?.element) {
        const nextSelector =
          typeof nextStep.element === 'string' ? nextStep.element : null;

        if (selectorNeedsSidebar(nextSelector)) {
          await ensureMobileSidebarOpen();
        }
        if (selectorNeedsSettingsExpanded(nextSelector)) {
          await ensureSettingsExpanded();
        }

        const nextEl = nextSelector
          ? document.querySelector(nextSelector)
          : null;
        nextEl?.click?.();

        /* eslint-disable no-underscore-dangle */
        const waitForPath = nextStep._commmateWaitForUrlIncludes;
        const waitForTimeout =
          nextStep._commmateWaitForUrlTimeout ?? step.waitForUrlTimeout ?? 5000;
        /* eslint-enable no-underscore-dangle */
        if (waitForPath) {
          await waitForUrlIncludes(waitForPath, waitForTimeout);
        } else {
          await delay(step.autoNavigateDelay ?? 300);
        }
      }

      // Allow custom hook to run too (if provided)
      if (step.onNextClick) {
        step.onNextClick(element, stepObj, {
          ...options,
          context,
          flow,
          driverRef,
        });
        return;
      }

      driverRef.current?.moveNext();
      driverRef.current?.refresh?.();
    };
  } else if (step.onNextClick) {
    driverStep.popover.onNextClick = (element, stepObj, options) => {
      step.onNextClick(element, stepObj, {
        ...options,
        context,
        flow,
        driverRef,
      });
    };
  }

  if (step.onPrevClick) {
    driverStep.popover.onPrevClick = (element, stepObj, options) => {
      step.onPrevClick(element, stepObj, {
        ...options,
        context,
        flow,
        driverRef,
      });
    };
  }

  if (step.onHighlighted) {
    driverStep.onHighlighted = (element, stepObj, options) => {
      step.onHighlighted(element, stepObj, {
        ...options,
        context,
        flow,
        driverRef,
      });
    };
  }

  // If configured, complete the current flow when the highlighted element is clicked.
  // Used for onboarding CTAs like "Continue" or "Add agents" so the tour doesn't re-run later
  // even if the user doesn't click an explicit "Done" button.
  if (step.completeFlowOnElementClick) {
    driverStep.onHighlighted = (element, stepObj, options) => {
      // Preserve any existing hook
      if (step.onHighlighted) {
        step.onHighlighted(element, stepObj, {
          ...options,
          context,
          flow,
          driverRef,
        });
      }

      if (!element || !element.addEventListener) return;

      const handler = () => {
        // Let the app handler run first (navigation/form submit), then close tour
        setTimeout(() => driverRef.current?.destroy(), 50);
      };

      // Store handler reference for cleanup
      /* eslint-disable no-param-reassign, no-underscore-dangle */
      stepObj._commmateCompleteOnClick = handler;
      /* eslint-enable no-param-reassign, no-underscore-dangle */
      element.addEventListener('click', handler, { once: true });
    };

    driverStep.onDeselected = (element, stepObj) => {
      // eslint-disable-next-line no-underscore-dangle
      const handler = stepObj?._commmateCompleteOnClick;
      if (handler && element?.removeEventListener) {
        element.removeEventListener('click', handler);
      }
    };
  }

  return driverStep;
}

/**
 * Create a skip button for the popover
 * @param {Object} driverRef - Reference wrapper { current: driver.js instance }
 * @param {Object} flow - Flow definition
 * @param {Object} context - Tour context
 */
function createSkipButton(driverRef, flow, context) {
  const { t } = context;
  const skipBtn = document.createElement('button');
  skipBtn.innerText = resolveI18n(t, 'TOUR.BUTTONS.SKIP', 'Skip');

  // Use larger touch targets on mobile
  const baseClasses =
    'driver-popover-skip-btn ml-2 text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2 rounded transition-colors';
  const sizeClasses = isMobileViewport()
    ? 'px-4 py-3 text-base min-h-[44px]'
    : 'px-3 py-1 text-sm';

  skipBtn.className = `${baseClasses} ${sizeClasses}`;

  skipBtn.addEventListener('click', async () => {
    const { uiSettings, updateUISettings, accountId } = context;
    const payload = markFlowSkipped(uiSettings, accountId, flow.id);
    await updateUISettings(payload);
    driverRef.current?.destroy();
  });

  return skipBtn;
}

/**
 * Create a "Bring me there" button for navigation steps
 * @param {Object} driverRef - Reference wrapper { current: driver.js instance }
 * @param {Object} step - Step definition
 * @param {Object} context - Tour context
 * @returns {HTMLButtonElement}
 */
function createBringMeThereButton(driverRef, step, context) {
  const { t } = context;
  const btn = document.createElement('button');
  const defaultLabel = resolveI18n(
    t,
    'TOUR.BUTTONS.BRING_ME_THERE',
    'Bring me there'
  );
  btn.innerText = step.bringMeThereLabel || defaultLabel;

  // Use larger touch targets on mobile
  const baseClasses =
    'driver-popover-navigate-btn bg-woot-500 text-white hover:bg-woot-600 rounded transition-colors';
  const sizeClasses = isMobileViewport()
    ? 'px-4 py-3 text-base min-h-[44px]'
    : 'px-3 py-1 text-sm';

  btn.className = `${baseClasses} ${sizeClasses}`;

  btn.addEventListener('click', async () => {
    if (step.navigateTo && context.navigateTo) {
      await context.navigateTo(step.navigateTo);
      await delay(500);
    }
    driverRef.current?.moveNext();
  });

  return btn;
}

/**
 * Prepare and filter steps for a flow
 * @param {Object} flow - Flow definition
 * @param {Object} context - Tour context
 * @returns {Promise<Array>}
 */
async function prepareFlowSteps(flow, context) {
  const { checkPermissions, isFeatureEnabled } = context;

  // Filter by permissions and features
  let steps = filterStepsByPermissions(
    flow.steps,
    checkPermissions,
    isFeatureEnabled,
    context
  );

  // Validate elements exist
  const validSteps = [];
  // eslint-disable-next-line no-restricted-syntax
  for (const step of steps) {
    if (step.element) {
      const selector = typeof step.element === 'string' ? step.element : null;

      if (selector && selectorNeedsSidebar(selector)) {
        // eslint-disable-next-line no-await-in-loop
        await ensureMobileSidebarOpen();
      }
      if (selector && selectorNeedsSettingsExpanded(selector)) {
        // eslint-disable-next-line no-await-in-loop
        await ensureSettingsExpanded();
      }

      if (selector && step.waitForElement) {
        // eslint-disable-next-line no-await-in-loop
        const element = await waitForVisibleElement(
          selector,
          isMobileViewport() ? 6000 : 3000
        );
        if (element) validSteps.push(step);
      } else if (selector) {
        const el = document.querySelector(selector);
        if (el && elementVisible(el)) validSteps.push(step);
      } else {
        // Non-string elements (Element or function) - keep as-is
        validSteps.push(step);
      }
      // Skip steps where element doesn't exist
    } else {
      // Steps without elements always included
      validSteps.push(step);
    }
  }

  return validSteps;
}

/**
 * Start a specific flow
 * @param {string} flowId - Flow ID to start
 * @param {Object} context - Tour context
 * @returns {Promise<boolean>} Whether the flow was started
 */
export async function startFlow(flowId, context) {
  const flow = flowRegistry.get(flowId);
  if (!flow) {
    // eslint-disable-next-line no-console
    console.warn(`[Tour] Flow "${flowId}" not found`);
    return false;
  }

  // Inject mobile-friendly styles
  injectMobileStyles();

  // Stop any active flow
  if (activeDriver) {
    activeDriver.destroy();
    activeDriver = null;
    activeFlowId = null;
  }

  // Wait for DOM to settle
  await delay(300);

  // On mobile: open the sidebar early if this flow targets sidebar/menu items,
  // so driver.js can correctly compute element positions (otherwise popovers
  // can appear "floating" because targets are off-screen/hidden).
  if (
    isMobileViewport() &&
    flow.steps?.some(
      s => typeof s.element === 'string' && selectorNeedsSidebar(s.element)
    )
  ) {
    await ensureMobileSidebarOpen();
  }

  // Prepare steps
  const steps = await prepareFlowSteps(flow, context);

  if (steps.length === 0) {
    // eslint-disable-next-line no-console
    console.warn(`[Tour] No valid steps for flow "${flowId}"`);
    return false;
  }

  // Mobile-friendly configuration
  const isMobile = isMobileViewport();
  const { t } = context;

  // Translated button text
  const nextText = resolveI18n(t, 'TOUR.BUTTONS.NEXT', 'Next');
  const backText = resolveI18n(t, 'TOUR.BUTTONS.BACK', 'Back');
  const doneText = resolveI18n(t, 'TOUR.BUTTONS.DONE', 'Done');

  // We need a reference to the driver that we can pass to callbacks
  // Since we can't reference driverObj during its own initialization,
  // we use a wrapper object that gets populated after creation
  const driverRef = { current: null };

  // Create driver instance
  const driverObj = driver({
    showProgress: true,
    // Only show next/previous - no close button (user must use Done or Skip)
    showButtons: ['next', 'previous'],
    nextBtnText: isMobile ? nextText : `${nextText} →`,
    prevBtnText: isMobile ? backText : `← ${backText}`,
    doneBtnText: doneText,
    popoverClass: 'commmate-tour',
    overlayColor: 'rgba(0, 0, 0, 0.5)',
    // Smaller padding on mobile to fit more content
    stagePadding: isMobile ? 4 : 8,
    stageRadius: 8,
    // Prevent closing by clicking overlay or pressing Escape
    allowClose: false,
    // Prevent overlay clicks from closing or advancing the tour
    overlayClickBehavior: () => {},
    // Lock interaction with active element by default; can be overridden per-step
    disableActiveInteraction: true,
    animate: true,
    // Enable smooth scrolling for better mobile experience
    smoothScroll: true,
    // Disable keyboard on mobile (touch is primary)
    allowKeyboardControl: !isMobile,
    steps: steps.map(step => transformStep(step, context, flow, driverRef)),

    onPopoverRender: (popover, options) => {
      ensureInteractionShield();
      // Add skip button if flow allows it
      if (flow.allowSkip !== false) {
        const footerButtons = popover.footerButtons;
        if (footerButtons) {
          const skipBtn = createSkipButton(driverRef, flow, context);
          footerButtons.appendChild(skipBtn);
        }
      }

      // Check if current step has "bring me there" navigation
      const currentStepIndex = options.state.activeIndex;
      const currentStep = steps[currentStepIndex];
      if (currentStep?.navigateTo) {
        const footerButtons = popover.footerButtons;
        if (footerButtons) {
          const navigateBtn = createBringMeThereButton(
            driverRef,
            currentStep,
            context
          );
          footerButtons.insertBefore(navigateBtn, footerButtons.firstChild);
        }
      }

      // Call step-level onPopoverRender if defined
      if (currentStep?.onPopoverRender) {
        currentStep.onPopoverRender(popover, {
          ...options,
          context,
          flow,
          driverRef,
        });
      }
    },

    onDestroyStarted: async () => {
      const { uiSettings, updateUISettings, accountId } = context;

      // Mark flow as complete
      const payload = markFlowComplete(uiSettings, accountId, flow.id);
      await updateUISettings(payload);

      activeDriver = null;
      activeFlowId = null;

      driverRef.current.destroy();
    },
    onDestroyed: () => {
      removeInteractionShield();

      // Only navigate to conversations for main features tours, not onboarding flows
      const isFeaturesTour =
        flow.id === 'adminFeatures' || flow.id === 'agentFeatures';
      if (isFeaturesTour) {
        const { accountId, navigateTo } = context;
        if (navigateTo && accountId) {
          navigateTo({ name: 'home', params: { accountId } }).catch(() => {
            // Fallback to direct navigation if router fails
            window.location.href = `/app/accounts/${accountId}/dashboard`;
          });
        }
      }
    },
  });

  // Store driver reference for callbacks
  driverRef.current = driverObj;

  activeDriver = driverObj;
  activeFlowId = flowId;

  driverObj.drive();
  return true;
}

/**
 * Stop the currently active flow
 */
export function stopActiveFlow() {
  if (activeDriver) {
    activeDriver.destroy();
    activeDriver = null;
    activeFlowId = null;
  }
}

/**
 * Get the currently active flow ID
 * @returns {string|null}
 */
export function getActiveFlowId() {
  return activeFlowId;
}

/**
 * Check if any flow is currently active
 * @returns {boolean}
 */
export function isFlowActive() {
  return activeDriver !== null;
}

/**
 * Try to start the appropriate flow for the current route
 * @param {Object} route - Vue Router route object
 * @param {Object} context - Tour context
 * @returns {Promise<boolean>} Whether a flow was started
 */
export async function maybeStartFlowForRoute(route, context) {
  // Don't start if a flow is already active
  if (activeDriver) {
    return false;
  }

  const flow = findFlowForRoute(route, context);
  if (!flow) {
    return false;
  }

  // Wait for DOM to settle after navigation
  await delay(800);

  return startFlow(flow.id, context);
}

/**
 * Restart a specific flow (clears completion and starts fresh)
 * @param {string} flowId - Flow ID to restart
 * @param {Object} context - Tour context
 * @returns {Promise<boolean>}
 */
export async function restartFlow(flowId, context) {
  const flow = flowRegistry.get(flowId);
  if (!flow) {
    return false;
  }

  // Clear completion state for this flow
  const { clearFlowCompletion } = await import('./state');
  const { uiSettings, updateUISettings, accountId } = context;
  const payload = clearFlowCompletion(uiSettings, accountId, flowId);
  await updateUISettings(payload);

  // Navigate to the flow's first route if specified
  if (flow.startRoute && context.navigateTo) {
    await context.navigateTo(flow.startRoute);
    await delay(500);
  }

  return startFlow(flowId, context);
}
