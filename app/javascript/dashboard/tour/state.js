/**
 * Tour state management
 *
 * Persists tour completion flags in ui_settings.
 *
 * Data model:
 *   commmate_tour_v2: {
 *     [accountId]: {
 *       flows: {
 *         [flowId]: { completedAt?, skippedAt? }
 *       }
 *     }
 *   }
 */

const TOUR_VERSION = 'commmate_tour_v2';

/**
 * Get flow state from ui_settings
 * @param {Object} uiSettings - Current ui_settings object
 * @param {number|string} accountId - Current account ID
 * @param {string} flowId - Flow identifier
 * @returns {Object} Flow state { completedAt?, skippedAt? }
 */
export function getFlowState(uiSettings, accountId, flowId) {
  const tourData = uiSettings?.[TOUR_VERSION] || {};
  const accountData = tourData[accountId] || {};
  const flowsData = accountData.flows || {};
  return flowsData[flowId] || {};
}

/**
 * Check if a flow is completed
 * @param {Object} uiSettings - Current ui_settings object
 * @param {number|string} accountId - Current account ID
 * @param {string} flowId - Flow identifier
 * @returns {boolean}
 */
export function isFlowCompleted(uiSettings, accountId, flowId) {
  const state = getFlowState(uiSettings, accountId, flowId);
  return !!state.completedAt;
}

/**
 * Check if a flow is skipped
 * @param {Object} uiSettings - Current ui_settings object
 * @param {number|string} accountId - Current account ID
 * @param {string} flowId - Flow identifier
 * @returns {boolean}
 */
export function isFlowSkipped(uiSettings, accountId, flowId) {
  const state = getFlowState(uiSettings, accountId, flowId);
  return !!state.skippedAt;
}

/**
 * Mark a flow as completed
 * @param {Object} uiSettings - Current ui_settings object
 * @param {number|string} accountId - Current account ID
 * @param {string} flowId - Flow identifier
 * @returns {Object} Updated ui_settings payload
 */
export function markFlowComplete(uiSettings, accountId, flowId) {
  const existingTourData = uiSettings?.[TOUR_VERSION] || {};
  const existingAccountData = existingTourData[accountId] || {};
  const existingFlowsData = existingAccountData.flows || {};

  return {
    [TOUR_VERSION]: {
      ...existingTourData,
      [accountId]: {
        ...existingAccountData,
        flows: {
          ...existingFlowsData,
          [flowId]: {
            ...existingFlowsData[flowId],
            completedAt: new Date().toISOString(),
          },
        },
      },
    },
  };
}

/**
 * Mark a flow as skipped
 * @param {Object} uiSettings - Current ui_settings object
 * @param {number|string} accountId - Current account ID
 * @param {string} flowId - Flow identifier
 * @returns {Object} Updated ui_settings payload
 */
export function markFlowSkipped(uiSettings, accountId, flowId) {
  const existingTourData = uiSettings?.[TOUR_VERSION] || {};
  const existingAccountData = existingTourData[accountId] || {};
  const existingFlowsData = existingAccountData.flows || {};

  return {
    [TOUR_VERSION]: {
      ...existingTourData,
      [accountId]: {
        ...existingAccountData,
        flows: {
          ...existingFlowsData,
          [flowId]: {
            ...existingFlowsData[flowId],
            skippedAt: new Date().toISOString(),
          },
        },
      },
    },
  };
}

/**
 * Clear completion/skip state for a flow (for restart)
 * @param {Object} uiSettings - Current ui_settings object
 * @param {number|string} accountId - Current account ID
 * @param {string} flowId - Flow identifier
 * @returns {Object} Updated ui_settings payload
 */
export function clearFlowCompletion(uiSettings, accountId, flowId) {
  const existingTourData = uiSettings?.[TOUR_VERSION] || {};
  const existingAccountData = existingTourData[accountId] || {};
  const existingFlowsData = existingAccountData.flows || {};

  // Remove the flow's state entirely
  const { [flowId]: _, ...restFlowsData } = existingFlowsData;

  return {
    [TOUR_VERSION]: {
      ...existingTourData,
      [accountId]: {
        ...existingAccountData,
        flows: restFlowsData,
      },
    },
  };
}

/**
 * Clear all flow completions for an account (full reset)
 * @param {Object} uiSettings - Current ui_settings object
 * @param {number|string} accountId - Current account ID
 * @returns {Object} Updated ui_settings payload
 */
export function clearAllFlowCompletions(uiSettings, accountId) {
  const existingTourData = uiSettings?.[TOUR_VERSION] || {};

  return {
    [TOUR_VERSION]: {
      ...existingTourData,
      [accountId]: {
        flows: {},
      },
    },
  };
}
