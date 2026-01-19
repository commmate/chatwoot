/**
 * Tour permissions helper
 *
 * Provides permission-based step filtering using existing policy infrastructure.
 */

import { FEATURE_FLAGS } from 'dashboard/featureFlags';

// Map feature flags to their string identifiers
export const TOUR_FEATURE_FLAGS = {
  CAMPAIGNS: FEATURE_FLAGS.CAMPAIGNS,
  WHATSAPP_CAMPAIGNS: FEATURE_FLAGS.WHATSAPP_CAMPAIGNS,
  CANNED_RESPONSES: FEATURE_FLAGS.CANNED_RESPONSES,
  MACROS: FEATURE_FLAGS.MACROS,
  TEAM_MANAGEMENT: FEATURE_FLAGS.TEAM_MANAGEMENT,
  LABELS: FEATURE_FLAGS.LABELS,
  REPORTS: FEATURE_FLAGS.REPORTS,
  AUTOMATIONS: FEATURE_FLAGS.AUTOMATIONS,
  INBOX_MANAGEMENT: FEATURE_FLAGS.INBOX_MANAGEMENT,
  AGENT_MANAGEMENT: FEATURE_FLAGS.AGENT_MANAGEMENT,
};

// Permissions required for tour steps
export const TOUR_PERMISSIONS = {
  INBOXES_MANAGE: ['administrator', 'settings_inboxes_manage'],
  AGENTS_MANAGE: ['administrator', 'agent_manage'],
  TEAMS_MANAGE: ['administrator', 'settings_teams_manage'],
  LABELS_MANAGE: ['administrator', 'label_manage'],
  REPORTS_VIEW: ['administrator', 'report_manage'],
  AUTOMATION_MANAGE: ['administrator', 'settings_automation_manage'],
  CAMPAIGNS_MANAGE: ['administrator', 'campaign_manage'],
  TEMPLATES_MANAGE: ['administrator', 'templates_manage'],
  CANNED_MANAGE: ['administrator', 'canned_response_manage'],
  MACROS_MANAGE: ['administrator', 'macro_manage'],
  CONVERSATION_MANAGE: ['administrator', 'conversation_manage'],
};

/**
 * Filter steps based on user permissions and feature flags
 * @param {Array} steps - Array of tour steps
 * @param {Function} checkPermissions - usePolicy().checkPermissions function
 * @param {Function} isFeatureEnabled - Function to check if feature flag is enabled
 * @param {Object} context - Additional context (hasWhatsAppCloud, isAIEnabled, etc.)
 * @returns {Array} Filtered steps the user can access
 */
export function filterStepsByPermissions(
  steps,
  checkPermissions,
  isFeatureEnabled,
  context = {}
) {
  return steps.filter(step => {
    // Check required permissions
    if (step.requiredPermissions?.length) {
      if (!checkPermissions(step.requiredPermissions)) {
        return false;
      }
    }

    // Check feature flag
    if (step.featureFlag) {
      if (!isFeatureEnabled(step.featureFlag)) {
        return false;
      }
    }

    // Check special conditions
    if (step.requiresWhatsAppCloud && !context.hasWhatsAppCloud) {
      return false;
    }

    if (step.requiresAI && !context.isAIEnabled) {
      return false;
    }

    // Check custom condition function
    if (step.condition && typeof step.condition === 'function') {
      if (!step.condition(context)) {
        return false;
      }
    }

    return true;
  });
}

/**
 * Check if user is an administrator
 * @param {Object} user - Current user object
 * @param {number|string} accountId - Account ID
 * @returns {boolean}
 */
export function isUserAdmin(user, accountId) {
  if (!user?.accounts?.length) return false;
  const account = user.accounts.find(a => a.id === Number(accountId));
  return account?.role === 'administrator';
}
