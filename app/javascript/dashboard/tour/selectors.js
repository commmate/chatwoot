/**
 * Tour DOM selectors
 *
 * Centralizes all selectors used by the guided tour.
 * Prefer existing stable elements; add data-tour attributes only where needed.
 */

export const SELECTORS = {
  // Evolution WhatsApp Setup (inbox creation)
  evolutionInboxName: '[data-tour="evolution-inbox-name"]',
  evolutionLoadQR: '[data-tour="evolution-load-qr"]',
  evolutionQRCode: '[data-tour="evolution-qr-code"]',
  evolutionContinue: '[data-tour="evolution-continue"]',

  // Add Agents step
  addAgentsMultiselect: '[data-tour="add-agents-multiselect"]',
  onboardNewAgentBtn: '[data-tour="onboard-new-agent"]',
  addAgentsSubmit: '[data-tour="add-agents-submit"]',

  // Finish Setup step
  finishBringMeThere: '[data-tour="finish-bring-me-there"]',

  // Sidebar navigation
  sidebarConversations: '[data-tour="sidebar-conversations"]',
  sidebarContacts: '[data-tour="sidebar-contacts"]',
  sidebarReports: '[data-tour="sidebar-reports"]',
  sidebarCampaigns: '[data-tour="sidebar-campaigns"]',
  sidebarSettings: '[data-tour="sidebar-settings"]',

  // Settings sub-items
  settingsInboxes: '[data-tour="settings-inboxes"]',
  settingsAgents: '[data-tour="settings-agents"]',
  settingsTeams: '[data-tour="settings-teams"]',
  settingsCannedResponses: '[data-tour="settings-canned-responses"]',
  settingsMacros: '[data-tour="settings-macros"]',
  settingsAutomation: '[data-tour="settings-automation"]',
  settingsLabels: '[data-tour="settings-labels"]',

  // Conversations view
  conversationList: '.conversation-panel, [class*="conversation-list"]',
  conversationItem: '.conversation, [class*="conversation-item"]',
  replyBox: '[data-tour="reply-box"]',
  aiAssistButton: '[data-tour="ai-assist-button"]',
  attachFileButton: '[data-tour="attach-file-button"]',
  audioRecorderButton: '[data-tour="audio-recorder-button"]',
  resolveAction: '[data-tour="resolve-action"]',
  sidepanelSwitch: '[data-tour="sidepanel-switch"]',
  sidepanelContactToggle: '[data-tour="sidepanel-contact-toggle"]',

  // Conversation side panel
  sidepanelAssignAgent: '[data-tour="sidepanel-assign-agent"]',
  sidepanelAssignTeam: '[data-tour="sidepanel-assign-team"]',
  sidepanelAssignPriority: '[data-tour="sidepanel-assign-priority"]',
  sidepanelLabels: '[data-tour="sidepanel-labels"]',

  // Templates
  templatesPage: 'a[href*="/templates"]',

  // Campaigns
  campaignsPage: 'a[href*="/campaigns"]',

  // Fallback page headers
  pageHeader: '.page-header, .settings-header, h1',
};
