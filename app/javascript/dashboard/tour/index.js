/**
 * CommMate Tour Module
 *
 * Provides guided walkthroughs for admins and agents using modular flows.
 *
 * Usage:
 *   import { initializeTourAutoStart } from 'dashboard/tour';
 *   initializeTourAutoStart(router, store);
 *
 * The tour auto-starts based on the current route and user role.
 * Flow completion is persisted in ui_settings.
 */

// Flow engine - core tour orchestration
export {
  startFlow,
  restartFlow,
  stopActiveFlow,
  isFlowActive,
  getActiveFlowId,
  maybeStartFlowForRoute,
  registerFlow,
  getFlowRegistry,
} from './flowEngine';

// Auto-start - router integration
export { initializeTourAutoStart } from './autoStart';

// State management - persistence
export {
  isFlowCompleted,
  isFlowSkipped,
  markFlowComplete,
  markFlowSkipped,
  clearFlowCompletion,
  clearAllFlowCompletions,
} from './state';

// Permission helpers
export {
  isUserAdmin,
  TOUR_PERMISSIONS,
  TOUR_FEATURE_FLAGS,
} from './permissions';

// Flow definitions
export {
  adminOnboardingEvolutionQr,
  adminOnboardingAddAgents,
  adminOnboardingFinish,
  adminFeatures,
  agentFeatures,
} from './flows';
