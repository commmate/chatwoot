# CommMate Tour Engine

The Tour Engine provides guided walkthroughs for new users using [driver.js](https://driverjs.com/). It supports multiple flows, role-based tours, i18n translations, and mobile-friendly layouts.

## Architecture

```
app/javascript/dashboard/tour/
├── index.js              # Public API exports
├── autoStart.js          # Router integration & context builder
├── flowEngine.js         # Core tour orchestration (driver.js wrapper)
├── state.js              # Persistence (ui_settings)
├── permissions.js        # Permission & feature flag checks
├── selectors.js          # DOM selectors for tour targets
├── waitFor.js            # Async utilities
├── i18nHelper.js         # Translation helper for non-Vue context
└── flows/                # Flow definitions
    ├── index.js          # Flow registry
    ├── adminOnboardingEvolutionQr.js
    ├── adminOnboardingAddAgents.js
    ├── adminOnboardingFinish.js
    ├── adminFeatures.js
    └── agentFeatures.js
```

## Key Concepts

### Flows

A **flow** is a sequence of tour steps triggered by specific conditions:

```javascript
{
  id: 'myFlow',           // Unique identifier
  role: 'admin',          // 'admin' or 'agent'
  allowSkip: true,        // Can user skip the flow?
  routes: ['home'],       // Routes that trigger this flow
  startRoute: { name: 'home' }, // Route for restart
  prerequisites: ctx => ctx.inboxes.length === 0, // Optional condition
  steps: [/* ... */]
}
```

### Steps

A **step** defines a single tour tooltip:

```javascript
{
  id: 'step-id',
  element: SELECTORS.someElement,  // DOM selector (optional)
  waitForElement: true,            // Wait for element to exist
  popover: {
    titleKey: 'TOUR.ADMIN_FEATURES.WELCOME.TITLE',
    descriptionKey: 'TOUR.ADMIN_FEATURES.WELCOME.DESCRIPTION',
    side: 'right',                 // top, bottom, left, right
    align: 'start',                // start, center, end
    mobileSide: 'bottom',          // Override for mobile
  },
  
  // Conditional display
  requiredPermissions: ['permission_name'],
  featureFlag: 'FEATURE_FLAG_NAME',
  requiresAI: true,
  requiresWhatsAppCloud: true,
  condition: (context) => boolean,
  
  // Navigation
  autoNavigateOnNext: true,
  waitForUrlIncludes: '/path',
  navigateBeforeHighlightDesktop: { name: 'routeName' },
  
  // Interaction
  allowInteraction: true,
  completeFlowOnElementClick: true,
}
```

## How It Works

### 1. Initialization

```javascript
// routes/index.js
import { initializeTourAutoStart } from 'dashboard/tour';

export const initalizeRouter = () => {
  // ... router setup ...
  initializeTourAutoStart(router, store);
};
```

### 2. Route Change Detection

On every route change, `autoStart.js`:
1. Builds a tour context with user info, permissions, and helpers
2. Sets the i18n locale based on user preferences
3. Calls `maybeStartFlowForRoute()` to find a matching flow
4. Starts the flow if conditions are met

### 3. Flow Matching

`flowEngine.js` checks each registered flow:
1. Does the route match?
2. Does the user role match?
3. Is the flow already completed/skipped?
4. Do prerequisites pass?

### 4. Step Rendering

For each step:
1. Resolves i18n keys to translated text
2. Validates the target element exists
3. Handles mobile sidebar/settings expansion
4. Renders the driver.js popover

### 5. Persistence

Flow completion is stored in `ui_settings`:

```json
{
  "commmate_tour_v2": {
    "9": {
      "flows": {
        "adminFeatures": { "completedAt": "2024-01-15T..." },
        "adminOnboardingEvolutionQr": { "skippedAt": "2024-01-15T..." }
      }
    }
  }
}
```

## Adding a New Flow

### 1. Create the Flow File

```javascript
// tour/flows/myNewFlow.js
import { SELECTORS } from '../selectors';
import { TOUR_PERMISSIONS, TOUR_FEATURE_FLAGS } from '../permissions';

export default {
  id: 'myNewFlow',
  role: 'admin',
  allowSkip: true,
  routes: ['route_name'],
  startRoute: { name: 'route_name' },

  steps: [
    {
      id: 'step-1',
      popover: {
        titleKey: 'TOUR.MY_FLOW.STEP1.TITLE',
        descriptionKey: 'TOUR.MY_FLOW.STEP1.DESCRIPTION',
        side: 'bottom',
        align: 'center',
      },
    },
    {
      id: 'step-2',
      element: SELECTORS.myElement,
      waitForElement: true,
      popover: {
        titleKey: 'TOUR.MY_FLOW.STEP2.TITLE',
        descriptionKey: 'TOUR.MY_FLOW.STEP2.DESCRIPTION',
        side: 'right',
        align: 'start',
      },
      requiredPermissions: TOUR_PERMISSIONS.SOME_PERMISSION,
    },
  ],
};
```

### 2. Register the Flow

```javascript
// tour/flows/index.js
import myNewFlow from './myNewFlow';

const flows = [
  // ... existing flows ...
  myNewFlow,
];
```

### 3. Add DOM Selectors

```javascript
// tour/selectors.js
export const SELECTORS = {
  myElement: '[data-tour="my-element"]',
};
```

Then in your Vue component:

```vue
<button data-tour="my-element">Click me</button>
```

### 4. Add Translations

Translations go in `settings.json` under the `TOUR` key:

**`i18n/locale/en/settings.json`:**
```json
{
  "TOUR": {
    "MY_FLOW": {
      "STEP1": {
        "TITLE": "Welcome!",
        "DESCRIPTION": "This is step 1."
      },
      "STEP2": {
        "TITLE": "Step 2",
        "DESCRIPTION": "This is step 2."
      }
    }
  }
}
```

**`i18n/locale/pt_BR/settings.json`:**
```json
{
  "TOUR": {
    "MY_FLOW": {
      "STEP1": {
        "TITLE": "Bem-vindo!",
        "DESCRIPTION": "Este é o passo 1."
      },
      "STEP2": {
        "TITLE": "Passo 2",
        "DESCRIPTION": "Este é o passo 2."
      }
    }
  }
}
```

> **Note:** Only `en` and `pt_BR` translations are maintained for CommMate.

## Step Options Reference

| Option | Type | Description |
|--------|------|-------------|
| `id` | string | Unique step identifier |
| `element` | string | CSS selector for target element |
| `waitForElement` | boolean | Wait for element to exist |
| `popover.titleKey` | string | i18n key for title |
| `popover.descriptionKey` | string | i18n key for description |
| `popover.side` | string | Popover position: top, bottom, left, right |
| `popover.align` | string | Alignment: start, center, end |
| `popover.mobileSide` | string | Override side for mobile |
| `requiredPermissions` | array | Required user permissions |
| `featureFlag` | string | Required feature flag |
| `requiresAI` | boolean | Requires AI integration |
| `requiresWhatsAppCloud` | boolean | Requires WhatsApp Cloud inbox |
| `condition` | function | Custom condition `(context) => boolean` |
| `autoNavigateOnNext` | boolean | Click element on "Next" |
| `waitForUrlIncludes` | string | Wait for URL to include path |
| `navigateBeforeHighlightDesktop` | object | Navigate before showing (desktop) |
| `allowInteraction` | boolean | Allow clicking highlighted element |
| `completeFlowOnElementClick` | boolean | Complete flow when element clicked |

## Tour Context

Available in `condition` functions and callbacks:

```javascript
{
  user,                  // Current user object
  accountId,             // Current account ID
  uiSettings,            // User's ui_settings
  isAdmin,               // Is user an admin?
  inboxes,               // List of inboxes
  hasWhatsAppCloud,      // Has WhatsApp Cloud inbox?
  isAIEnabled,           // Is OpenAI integration enabled?
  checkPermissions,      // Function to check permissions
  isFeatureEnabled,      // Function to check feature flags
  updateUISettings,      // Function to save ui_settings
  navigateTo,            // Function to navigate (Vue Router)
  t,                     // Translation function
}
```

## Existing Flows

| Flow ID | Role | Trigger | Description |
|---------|------|---------|-------------|
| `adminOnboardingEvolutionQr` | admin | Evolution inbox setup | QR code scanning guide |
| `adminOnboardingAddAgents` | admin | Add agents page | Agent assignment guide |
| `adminOnboardingFinish` | admin | Inbox finish page | Setup completion |
| `adminFeatures` | admin | Home/Dashboard | Full feature tour |
| `agentFeatures` | agent | Home/Dashboard | Agent feature tour |

## Debugging

Check browser console for `[Tour]` prefixed messages:

```
[Tour] Route changed: home {accountId: 9}
[Tour] Context: {isAdmin: true, accountId: 9}
[Tour] Finding flow for route: home
[Tour] Starting flow: adminFeatures
```

### Reset Flow Completion

To test a flow again, clear its completion in browser console:

```javascript
// Clear all tour completions for current account
store.dispatch('updateUISettings', {
  uiSettings: {
    commmate_tour_v2: {
      [store.getters.getCurrentAccountId]: {
        flows: {}
      }
    }
  }
});
```

Then navigate to the flow's trigger route.
