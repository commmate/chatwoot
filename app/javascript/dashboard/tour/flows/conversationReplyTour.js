/**
 * Conversation Tour Flow
 *
 * Triggered when user opens a conversation for the first time.
 * Guides through the reply box features, then prompts user to open
 * the side panel and continues with side panel features.
 */

import { SELECTORS } from '../selectors';

export default {
  id: 'conversationReplyTour',
  role: 'all', // Both admin and agent
  allowSkip: true,

  // Trigger on any conversation view
  routes: [
    'inbox_conversation',
    'conversation_through_inbox',
    'conversations_through_label',
    'conversations_through_team',
    'conversations_through_folders',
    'conversation_through_mentions',
    'conversation_through_unattended',
    'conversation_through_participating',
  ],

  // No prerequisites - rely on waitForElement for each step
  prerequisites: () => true,

  steps: [
    // Reply box steps
    {
      id: 'reply-box-intro',
      element: SELECTORS.replyBox,
      waitForElement: true,
      popover: {
        titleKey: 'TOUR.CONVERSATION_REPLY.REPLY_BOX.TITLE',
        descriptionKey: 'TOUR.CONVERSATION_REPLY.REPLY_BOX.DESCRIPTION',
        side: 'top',
        align: 'center',
        mobileSide: 'top',
      },
    },
    {
      id: 'attach-file',
      element: SELECTORS.attachFileButton,
      waitForElement: true,
      popover: {
        titleKey: 'TOUR.CONVERSATION_REPLY.ATTACH_FILE.TITLE',
        descriptionKey: 'TOUR.CONVERSATION_REPLY.ATTACH_FILE.DESCRIPTION',
        side: 'top',
        align: 'start',
        mobileSide: 'top',
      },
    },
    {
      id: 'audio-recorder',
      element: SELECTORS.audioRecorderButton,
      waitForElement: true,
      popover: {
        titleKey: 'TOUR.CONVERSATION_REPLY.AUDIO_RECORDER.TITLE',
        descriptionKey: 'TOUR.CONVERSATION_REPLY.AUDIO_RECORDER.DESCRIPTION',
        side: 'top',
        align: 'start',
        mobileSide: 'top',
      },
      // Only show if audio button exists (conditional based on inbox type)
      condition: () => !!document.querySelector(SELECTORS.audioRecorderButton),
    },
    {
      id: 'ai-assist',
      element: SELECTORS.aiAssistButton,
      waitForElement: true,
      popover: {
        titleKey: 'TOUR.CONVERSATION_REPLY.AI_ASSIST.TITLE',
        descriptionKey: 'TOUR.CONVERSATION_REPLY.AI_ASSIST.DESCRIPTION',
        side: 'top',
        align: 'start',
        mobileSide: 'top',
      },
      // Only show if AI is enabled
      requiresAI: true,
    },
    {
      id: 'resolve-action',
      element: SELECTORS.resolveAction,
      waitForElement: true,
      popover: {
        titleKey: 'TOUR.CONVERSATION_REPLY.RESOLVE_ACTION.TITLE',
        descriptionKey: 'TOUR.CONVERSATION_REPLY.RESOLVE_ACTION.DESCRIPTION',
        side: 'bottom',
        align: 'end',
        mobileSide: 'bottom',
      },
    },
    // Side panel toggle - allow interaction to open the panel
    {
      id: 'sidepanel-toggle',
      element: SELECTORS.sidepanelContactToggle,
      waitForElement: true,
      allowInteraction: true,
      popover: {
        titleKey: 'TOUR.CONVERSATION_REPLY.SIDEPANEL_TOGGLE.TITLE',
        descriptionKey: 'TOUR.CONVERSATION_REPLY.SIDEPANEL_TOGGLE.DESCRIPTION',
        side: 'left',
        align: 'center',
        mobileSide: 'bottom',
      },
    },
    // Side panel steps - these wait for elements to appear after user opens panel
    {
      id: 'assign-agent',
      element: SELECTORS.sidepanelAssignAgent,
      waitForElement: true,
      popover: {
        titleKey: 'TOUR.CONVERSATION_SIDEPANEL.ASSIGN_AGENT.TITLE',
        descriptionKey: 'TOUR.CONVERSATION_SIDEPANEL.ASSIGN_AGENT.DESCRIPTION',
        side: 'left',
        align: 'start',
        mobileSide: 'bottom',
      },
    },
    {
      id: 'assign-team',
      element: SELECTORS.sidepanelAssignTeam,
      waitForElement: true,
      popover: {
        titleKey: 'TOUR.CONVERSATION_SIDEPANEL.ASSIGN_TEAM.TITLE',
        descriptionKey: 'TOUR.CONVERSATION_SIDEPANEL.ASSIGN_TEAM.DESCRIPTION',
        side: 'left',
        align: 'start',
        mobileSide: 'bottom',
      },
    },
    {
      id: 'assign-priority',
      element: SELECTORS.sidepanelAssignPriority,
      waitForElement: true,
      popover: {
        titleKey: 'TOUR.CONVERSATION_SIDEPANEL.ASSIGN_PRIORITY.TITLE',
        descriptionKey:
          'TOUR.CONVERSATION_SIDEPANEL.ASSIGN_PRIORITY.DESCRIPTION',
        side: 'left',
        align: 'start',
        mobileSide: 'bottom',
      },
    },
    {
      id: 'add-labels',
      element: SELECTORS.sidepanelLabels,
      waitForElement: true,
      popover: {
        titleKey: 'TOUR.CONVERSATION_SIDEPANEL.ADD_LABELS.TITLE',
        descriptionKey: 'TOUR.CONVERSATION_SIDEPANEL.ADD_LABELS.DESCRIPTION',
        side: 'left',
        align: 'start',
        mobileSide: 'bottom',
      },
    },
  ],
};
