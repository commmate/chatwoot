// Custom sidebar menu items for CommMate
// These will be injected into the main sidebar menu

export const customMenuItems = [
  {
    name: 'Kanban',
    label: 'KANBAN.TITLE',
    icon: 'i-lucide-kanban-square',
    to: 'kanban_board',
    activeOn: ['kanban_board'],
    // Insert after Conversations, before Captain
    insertAfter: 'Conversation',
  },
];

export default customMenuItems;

