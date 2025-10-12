# Custom Extensions Integration Guide

## Kanban Board Integration

The kanban board has been created in `custom/app/javascript/dashboard/routes/dashboard/kanban/`.

### Manual Integration Steps (Required)

Since we're keeping core files minimal, you need to manually integrate the custom routes and menu items:

## Step 1: Register Kanban Routes

**File:** `app/javascript/dashboard/routes/dashboard/dashboard.routes.js`

Add this import at the top:
```javascript
// After other imports (around line 11)
import customRoutes from '../../../../custom/app/javascript/dashboard/routes/customRoutes';
```

Add custom routes to the children array (around line 28):
```javascript
children: [
  ...captainRoutes,
  ...inboxRoutes,
  ...conversation.routes,
  ...customRoutes.routes,  // <-- Add this line
  ...settings.routes,
  ...contactRoutes,
  ...searchRoutes,
  ...notificationRoutes,
  ...helpcenterRoutes.routes,
  ...campaignsRoutes.routes,
],
```

## Step 2: Add Kanban to Sidebar Menu

**File:** `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`

### Option A: Add as Top-Level Item

Add after the Conversations menu item (around line 214):

```javascript
{
  name: 'Kanban',
  label: t('KANBAN.TITLE'),
  icon: 'i-lucide-kanban-square',
  to: accountScopedRoute('kanban_board'),
  activeOn: ['kanban_board'],
},
```

### Option B: Add Under Conversations Submenu

Add to the Conversation children array (around line 213):

```javascript
{
  name: 'Conversation',
  label: t('SIDEBAR.CONVERSATIONS'),
  icon: 'i-lucide-message-circle',
  children: [
    {
      name: 'All',
      label: t('SIDEBAR.ALL_CONVERSATIONS'),
      activeOn: ['inbox_conversation'],
      to: accountScopedRoute('home'),
    },
    {
      name: 'Kanban',  // <-- Add this
      label: t('KANBAN.TITLE'),
      activeOn: ['kanban_board'],
      to: accountScopedRoute('kanban_board'),
    },
    {
      name: 'Mentions',
      label: t('SIDEBAR.MENTIONED_CONVERSATIONS'),
      activeOn: ['conversation_through_mentions'],
      to: accountScopedRoute('conversation_mentions'),
    },
    // ... rest of children
  ],
},
```

## Step 3: Load i18n Translations

**File:** `app/javascript/dashboard/i18n/index.js`

Import and merge custom translations:

```javascript
// At the top, add import
import customKanbanEn from '../../../custom/app/javascript/dashboard/i18n/locale/en/kanban.json';

// In the locale loading section, merge custom translations:
const loadLocale = (locale) => {
  // ... existing code ...
  
  // Merge custom translations
  const customTranslations = locale === 'en' ? customKanbanEn : {};
  return {
    ...defaultMessages,
    ...customTranslations,
  };
};
```

## Alternative: Automatic Loading (Advanced)

If you want automatic loading without core modifications, create an initializer:

**File:** `custom/config/initializers/load_custom_frontend.rb`

```ruby
# This would require ejecting and customizing the Vite build
# For now, manual integration is simpler and more maintainable
```

## Step 4: Rebuild Assets

After making these changes:

```bash
# If running locally (not Docker)
pnpm dev

# If running in Docker
podman build --build-arg RAILS_ENV=development --build-arg BUNDLE_WITHOUT="" -t chatwoot:commmate-dev -f ./docker/Dockerfile .
podman-compose -f docker-compose.commmate.yaml up -d --force-recreate
```

## Testing

1. Login to Chatwoot: http://localhost:3000
2. Look for "Kanban" in the sidebar (under Conversations or as top-level)
3. Click to open the kanban board
4. Drag conversations between columns
5. Verify status updates work

## Summary of Core File Changes

This integration requires modifications to **2 core files**:

1. `app/javascript/dashboard/routes/dashboard/dashboard.routes.js` (1 line import, 1 line in children)
2. `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` (6-8 lines for menu item)
3. `app/javascript/dashboard/i18n/index.js` (2 lines for translations)

**Total:** ~10-15 lines across 3 files

These changes are:
- ✅ Easy to maintain during upstream merges
- ✅ Clearly marked as CommMate customizations
- ✅ Non-invasive to core functionality
- ✅ Can be git-tracked and documented

## Future Enhancement

To make this even cleaner, you could:
1. Create a plugin system for custom routes (contribute to Chatwoot!)
2. Use a vite plugin to auto-load custom routes
3. Create a custom build pipeline

For now, the manual integration is the cleanest approach while maintaining upstream compatibility.

