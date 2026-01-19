/**
 * Admin Features Flow
 *
 * Comprehensive tour of CommMate features for administrators.
 * Triggered on first visit to the main conversations page (home).
 * Includes navigation helpers for multi-page features.
 */

import { SELECTORS } from '../selectors';
import { TOUR_PERMISSIONS, TOUR_FEATURE_FLAGS } from '../permissions';

export default {
  id: 'adminFeatures',
  role: 'admin',
  allowSkip: true,

  // Trigger on main conversations page
  routes: ['home', 'inbox_dashboard'],

  // Start route for restart functionality
  startRoute: { name: 'home' },

  steps: [
    // --- Welcome ---
    {
      id: 'admin-features-welcome',
      popover: {
        titleKey: 'TOUR.ADMIN_FEATURES.WELCOME.TITLE',
        descriptionKey: 'TOUR.ADMIN_FEATURES.WELCOME.DESCRIPTION',
        side: 'bottom',
        align: 'center',
      },
    },

    // --- Conversations ---
    {
      id: 'sidebar-conversations',
      element: SELECTORS.sidebarConversations,
      waitForElement: true,
      autoNavigateOnNext: true,
      waitForUrlIncludes: '/dashboard',
      navigateBeforeHighlightDesktop: { name: 'home' },
      popover: {
        titleKey: 'TOUR.ADMIN_FEATURES.CONVERSATIONS.TITLE',
        descriptionKey: 'TOUR.ADMIN_FEATURES.CONVERSATIONS.DESCRIPTION',
        side: 'right',
        align: 'start',
      },
    },

    // --- Contacts ---
    {
      id: 'sidebar-contacts',
      element: SELECTORS.sidebarContacts,
      waitForElement: true,
      autoNavigateOnNext: true,
      waitForUrlIncludes: '/contacts',
      popover: {
        titleKey: 'TOUR.ADMIN_FEATURES.CONTACTS.TITLE',
        descriptionKey: 'TOUR.ADMIN_FEATURES.CONTACTS.DESCRIPTION',
        side: 'right',
        align: 'start',
      },
    },

    // --- Reports ---
    {
      id: 'sidebar-reports',
      element: SELECTORS.sidebarReports,
      waitForElement: true,
      autoNavigateOnNext: true,
      waitForUrlIncludes: '/reports',
      popover: {
        titleKey: 'TOUR.ADMIN_FEATURES.REPORTS.TITLE',
        descriptionKey: 'TOUR.ADMIN_FEATURES.REPORTS.DESCRIPTION',
        side: 'right',
        align: 'start',
      },
      requiredPermissions: TOUR_PERMISSIONS.REPORTS_VIEW,
      featureFlag: TOUR_FEATURE_FLAGS.REPORTS,
    },

    // --- Campaigns ---
    {
      id: 'sidebar-campaigns',
      element: SELECTORS.sidebarCampaigns,
      waitForElement: true,
      autoNavigateOnNext: true,
      waitForUrlIncludes: '/campaigns',
      popover: {
        titleKey: 'TOUR.ADMIN_FEATURES.CAMPAIGNS.TITLE',
        descriptionKey: 'TOUR.ADMIN_FEATURES.CAMPAIGNS.DESCRIPTION',
        side: 'right',
        align: 'start',
      },
      requiredPermissions: TOUR_PERMISSIONS.CAMPAIGNS_MANAGE,
      featureFlag: TOUR_FEATURE_FLAGS.CAMPAIGNS,
    },

    // --- WhatsApp Campaigns Note ---
    {
      id: 'campaigns-whatsapp-note',
      popover: {
        titleKey: 'TOUR.ADMIN_FEATURES.WHATSAPP_CAMPAIGNS_NOTE.TITLE',
        descriptionKey:
          'TOUR.ADMIN_FEATURES.WHATSAPP_CAMPAIGNS_NOTE.DESCRIPTION',
        side: 'bottom',
        align: 'center',
      },
      requiredPermissions: TOUR_PERMISSIONS.CAMPAIGNS_MANAGE,
      featureFlag: TOUR_FEATURE_FLAGS.WHATSAPP_CAMPAIGNS,
      condition: context => !context.hasWhatsAppCloud,
    },

    // --- Settings ---
    {
      id: 'sidebar-settings',
      element: SELECTORS.sidebarSettings,
      waitForElement: true,
      allowInteraction: false,
      autoNavigateOnNext: true,
      waitForUrlIncludes: '/settings',
      popover: {
        titleKey: 'TOUR.ADMIN_FEATURES.SETTINGS.TITLE',
        descriptionKey: 'TOUR.ADMIN_FEATURES.SETTINGS.DESCRIPTION',
        side: 'right',
        align: 'start',
      },
      onHighlightStarted: () => {
        try {
          const key = 'next-sidebar-expanded-item';
          const value = JSON.stringify('Settings');
          sessionStorage.setItem(key, value);
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
          // no-op
        }
      },
    },

    // --- Teams ---
    {
      id: 'settings-teams',
      element: SELECTORS.settingsTeams,
      waitForElement: true,
      autoNavigateOnNext: true,
      waitForUrlIncludes: '/settings/teams',
      popover: {
        titleKey: 'TOUR.ADMIN_FEATURES.TEAMS.TITLE',
        descriptionKey: 'TOUR.ADMIN_FEATURES.TEAMS.DESCRIPTION',
        side: 'right',
        align: 'start',
      },
      requiredPermissions: TOUR_PERMISSIONS.TEAMS_MANAGE,
      featureFlag: TOUR_FEATURE_FLAGS.TEAM_MANAGEMENT,
    },

    // --- Saved Replies ---
    {
      id: 'settings-canned-responses',
      element: SELECTORS.settingsCannedResponses,
      waitForElement: true,
      autoNavigateOnNext: true,
      waitForUrlIncludes: '/settings/canned-response',
      popover: {
        titleKey: 'TOUR.ADMIN_FEATURES.CANNED_RESPONSES.TITLE',
        descriptionKey: 'TOUR.ADMIN_FEATURES.CANNED_RESPONSES.DESCRIPTION',
        side: 'right',
        align: 'start',
      },
      requiredPermissions: TOUR_PERMISSIONS.CANNED_MANAGE,
      featureFlag: TOUR_FEATURE_FLAGS.CANNED_RESPONSES,
    },

    // --- Macros ---
    {
      id: 'settings-macros',
      element: SELECTORS.settingsMacros,
      waitForElement: true,
      autoNavigateOnNext: true,
      waitForUrlIncludes: '/settings/macros',
      popover: {
        titleKey: 'TOUR.ADMIN_FEATURES.MACROS.TITLE',
        descriptionKey: 'TOUR.ADMIN_FEATURES.MACROS.DESCRIPTION',
        side: 'right',
        align: 'start',
      },
      requiredPermissions: TOUR_PERMISSIONS.MACROS_MANAGE,
      featureFlag: TOUR_FEATURE_FLAGS.MACROS,
    },

    // --- Automation ---
    {
      id: 'settings-automation',
      element: SELECTORS.settingsAutomation,
      waitForElement: true,
      autoNavigateOnNext: true,
      waitForUrlIncludes: '/settings/automation',
      popover: {
        titleKey: 'TOUR.ADMIN_FEATURES.AUTOMATION.TITLE',
        descriptionKey: 'TOUR.ADMIN_FEATURES.AUTOMATION.DESCRIPTION',
        side: 'right',
        align: 'start',
      },
      requiredPermissions: TOUR_PERMISSIONS.AUTOMATION_MANAGE,
      featureFlag: TOUR_FEATURE_FLAGS.AUTOMATIONS,
    },

    // --- Labels ---
    {
      id: 'settings-labels',
      element: SELECTORS.settingsLabels,
      waitForElement: true,
      autoNavigateOnNext: true,
      waitForUrlIncludes: '/settings/labels',
      popover: {
        titleKey: 'TOUR.ADMIN_FEATURES.LABELS.TITLE',
        descriptionKey: 'TOUR.ADMIN_FEATURES.LABELS.DESCRIPTION',
        side: 'right',
        align: 'start',
      },
      requiredPermissions: TOUR_PERMISSIONS.LABELS_MANAGE,
      featureFlag: TOUR_FEATURE_FLAGS.LABELS,
    },

    // --- Templates (WhatsApp Cloud only) ---
    {
      id: 'templates-intro',
      element: SELECTORS.templatesPage,
      waitForElement: true,
      autoNavigateOnNext: true,
      waitForUrlIncludes: '/templates',
      popover: {
        titleKey: 'TOUR.ADMIN_FEATURES.TEMPLATES.TITLE',
        descriptionKey: 'TOUR.ADMIN_FEATURES.TEMPLATES.DESCRIPTION',
        side: 'bottom',
        align: 'start',
      },
      requiredPermissions: TOUR_PERMISSIONS.TEMPLATES_MANAGE,
      requiresWhatsAppCloud: true,
    },

    // --- AI Assistance ---
    {
      id: 'ai-assist-intro',
      element: SELECTORS.aiAssistButton,
      waitForElement: true,
      popover: {
        titleKey: 'TOUR.ADMIN_FEATURES.AI_ASSIST.TITLE',
        descriptionKey: 'TOUR.ADMIN_FEATURES.AI_ASSIST.DESCRIPTION',
        side: 'top',
        align: 'end',
      },
      requiresAI: true,
    },

    // --- Tour Complete ---
    {
      id: 'admin-tour-complete',
      popover: {
        titleKey: 'TOUR.ADMIN_FEATURES.COMPLETE.TITLE',
        descriptionKey: 'TOUR.ADMIN_FEATURES.COMPLETE.DESCRIPTION',
        side: 'bottom',
        align: 'center',
      },
    },
  ],
};
