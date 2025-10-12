# CommMate Extension Guidelines

This document explains how to extend Chatwoot for CommMate-specific features while maintaining easy upstream synchronization.

## Overview

CommMate uses Chatwoot's built-in extension system via the `custom/` directory. This approach mirrors how Chatwoot manages Enterprise Edition features and ensures zero conflicts when syncing with upstream.

## Architecture

```
chatwoot/
├── app/                    # Chatwoot OSS core
├── enterprise/             # Chatwoot Enterprise (if present)
├── custom/                 # CommMate customizations (YOU)
│   ├── app/
│   │   ├── models/
│   │   │   └── custom/
│   │   │       └── account.rb
│   │   ├── controllers/
│   │   ├── services/
│   │   ├── jobs/
│   │   └── views/
│   ├── config/
│   │   └── routes.rb
│   ├── lib/
│   └── spec/
└── README.md
```

### Load Order
1. Chatwoot OSS loads first
2. Enterprise Edition loads (if present) and extends/overrides OSS
3. **Custom loads last** and extends/overrides both OSS and Enterprise

## Getting Started

### 1. Create the Custom Directory Structure

```bash
mkdir -p custom/app/{models/custom,controllers,services/custom,jobs,views,helpers}
mkdir -p custom/config/initializers
mkdir -p custom/lib
mkdir -p custom/spec
```

### 2. Initialize the Custom Module Namespace

Create `custom/lib/custom.rb`:

```ruby
# frozen_string_literal: true

# Custom module namespace for CommMate extensions
module Custom
  # This module serves as the namespace for all CommMate custom extensions
end
```

### 3. Configure Rails to Load Custom Extensions (ONE CORE FILE CHANGE)

Add these lines to `config/application.rb` after the enterprise configuration (around line 53):

```ruby
# Load custom paths for CommMate extensions (mirrors enterprise structure)
if ChatwootApp.custom?
  config.eager_load_paths << Rails.root.join('custom/lib')
  config.eager_load_paths << Rails.root.join('custom/listeners')
  # rubocop:disable Rails/FilePath
  config.eager_load_paths += Dir["#{Rails.root}/custom/app/**"]
  # rubocop:enable Rails/FilePath
  config.paths['app/views'].unshift('custom/app/views')
  
  # Load custom initializers
  custom_initializers = Rails.root.join('custom/config/initializers')
  Dir[custom_initializers.join('**/*.rb')].each { |f| require f } if custom_initializers.exist?
end
```

**This is the ONLY core file you need to modify**. During upstream syncs, this block is easy to preserve with a simple rebase or merge conflict resolution.

### 4. Create a README

See `custom/README.md` for details.

### 5. Git Strategy

**Option A: Separate Branch (Recommended)**
```bash
# Main development branch with custom features
git checkout -b commmate-develop

# Track custom/ in this branch
git add custom/
git commit -m "Initialize CommMate custom extensions"

# Sync with upstream periodically
git fetch upstream
git checkout develop
git merge upstream/develop
git checkout commmate-develop
git rebase develop  # or merge develop
```

**Option B: Submodule**
```bash
# Keep custom/ as a separate git repository
git submodule add git@github.com:commmate/chatwoot-custom.git custom
```

## Extension Patterns

### Pattern 1: Extending Models

Use Ruby modules to add or override methods without modifying core files.

**`custom/app/models/custom/account.rb`**
```ruby
# frozen_string_literal: true

module Custom::Account
  # Add new methods
  def commmate_subscription_status
    # Your custom logic
    custom_attributes['commmate_subscription'] || 'free'
  end

  def commmate_feature_enabled?(feature_name)
    # Check if a CommMate feature is enabled
    commmate_features.include?(feature_name.to_s)
  end

  # Override existing methods (use super to call original)
  def inbox_ids
    ids = super
    # Apply CommMate-specific filtering
    ids.select { |id| commmate_inbox_allowed?(id) }
  end

  private

  def commmate_features
    custom_attributes['commmate_features'] || []
  end

  def commmate_inbox_allowed?(inbox_id)
    # Your logic here
    true
  end
end
```

The extension is automatically loaded via the prepend at the bottom of `app/models/account.rb`:
```ruby
Account.prepend_mod_with('Account')  # Loads Custom::Account
```

### Pattern 2: Extending Services

**`custom/app/services/custom/search_service.rb`**
```ruby
# frozen_string_literal: true

module Custom::SearchService
  # Override existing method
  def filter_messages
    messages = super  # Call original implementation
    
    # Add CommMate-specific filtering
    return messages unless commmate_advanced_search_enabled?
    
    messages.where(commmate_custom_filter: true)
  end

  # Add new method
  def commmate_semantic_search
    # Your custom search logic
    Message.where(account_id: current_account.id)
           .where("content ILIKE ?", "%#{search_query}%")
           .limit(50)
  end

  private

  def commmate_advanced_search_enabled?
    current_account.commmate_feature_enabled?(:advanced_search)
  end
end
```

At the bottom of `app/services/search_service.rb`, add:
```ruby
SearchService.prepend_mod_with('SearchService')
```

### Pattern 3: Adding New Controllers

**`custom/app/controllers/api/v1/accounts/commmate_features_controller.rb`**
```ruby
# frozen_string_literal: true

class Api::V1::Accounts::CommmateFeaturesController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    @features = Current.account.commmate_available_features
    render json: @features
  end

  def enable
    feature = params[:feature]
    if Current.account.commmate_enable_feature(feature)
      render json: { success: true, feature: feature }
    else
      render json: { error: 'Failed to enable feature' }, status: :unprocessable_entity
    end
  end

  private

  def check_authorization
    authorize(Current.account, :manage_commmate_features?)
  end
end
```

**`custom/config/routes.rb`**
```ruby
# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :accounts do
        scope module: :accounts do
          resources :commmate_features, only: [:index, :create] do
            post :enable, on: :collection
            post :disable, on: :collection
          end
        end
      end
    end
  end
end
```

### Pattern 4: Adding New Models

**`custom/app/models/commmate_integration.rb`**
```ruby
# frozen_string_literal: true

class CommmateIntegration < ApplicationRecord
  belongs_to :account
  has_many :commmate_sync_logs, dependent: :destroy

  validates :account_id, presence: true
  validates :integration_type, presence: true, inclusion: { in: %w[crm analytics billing] }

  enum status: { inactive: 0, active: 1, error: 2 }

  def sync!
    # Your sync logic
    CommmateIntegrationSyncJob.perform_later(id)
  end
end
```

**Migration** (generate in main app):
```bash
rails g migration CreateCommmateIntegrations account:references integration_type:string status:integer config:jsonb
```

### Pattern 5: Adding Background Jobs

**`custom/app/jobs/commmate_integration_sync_job.rb`**
```ruby
# frozen_string_literal: true

class CommmateIntegrationSyncJob < ApplicationJob
  queue_as :default

  def perform(integration_id)
    integration = CommmateIntegration.find(integration_id)
    
    # Your sync logic
    sync_service = CommmateIntegrationSyncService.new(integration)
    sync_service.perform
    
    integration.update!(
      last_synced_at: Time.current,
      status: :active
    )
  rescue StandardError => e
    integration.update!(status: :error)
    Rails.logger.error "CommMate sync failed: #{e.message}"
    raise e
  end
end
```

### Pattern 6: Extending Views/API Responses

**`custom/app/views/api/v1/accounts/show.json.jbuilder`**
```ruby
# frozen_string_literal: true

# This extends the existing account show view
json.partial! 'api/v1/accounts/account', account: @account

# Add CommMate-specific fields
json.commmate_features @account.commmate_features
json.commmate_subscription do
  json.status @account.commmate_subscription_status
  json.plan @account.commmate_plan
  json.expires_at @account.commmate_subscription_expires_at
end
```

### Pattern 7: Adding Frontend Components

**`custom/app/javascript/dashboard/routes/dashboard/settings/commmate/Index.vue`**
```vue
<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';

const { t } = useI18n();
const features = ref([]);

const fetchFeatures = async () => {
  // Fetch CommMate features
  const response = await axios.get('/api/v1/accounts/1/commmate_features');
  features.value = response.data;
};

onMounted(() => {
  fetchFeatures();
});
</script>

<template>
  <div class="flex flex-col gap-4 p-6">
    <h2 class="text-xl font-semibold">
      {{ t('COMMMATE_SETTINGS.TITLE') }}
    </h2>
    
    <div class="grid grid-cols-2 gap-4">
      <div
        v-for="feature in features"
        :key="feature.id"
        class="rounded-lg border border-slate-200 p-4"
      >
        <h3 class="font-medium">{{ feature.name }}</h3>
        <p class="text-sm text-slate-600">{{ feature.description }}</p>
      </div>
    </div>
  </div>
</template>
```

**`custom/app/javascript/dashboard/i18n/locale/en/commmate.json`**
```json
{
  "COMMMATE_SETTINGS": {
    "TITLE": "CommMate Features",
    "DESCRIPTION": "Manage your CommMate-specific features"
  }
}
```

## Common Use Cases

### 1. Custom Authentication Logic

**`custom/app/controllers/custom/devise_overrides/sessions_controller.rb`**
```ruby
module Custom::DeviseOverrides::SessionsController
  def create
    # Add CommMate-specific auth logic before regular login
    if commmate_requires_2fa?(params[:email])
      render json: { requires_2fa: true }, status: :unauthorized
      return
    end
    
    super  # Call original Devise logic
  end

  private

  def commmate_requires_2fa?(email)
    # Your logic
    false
  end
end
```

### 2. Custom Webhooks

**`custom/app/services/commmate/webhook_service.rb`**
```ruby
module Commmate
  class WebhookService
    def initialize(account, event_type, payload)
      @account = account
      @event_type = event_type
      @payload = payload
    end

    def deliver
      webhook_urls.each do |url|
        CommmateWebhookDeliveryJob.perform_later(url, @event_type, @payload)
      end
    end

    private

    def webhook_urls
      @account.custom_attributes['commmate_webhook_urls'] || []
    end
  end
end
```

### 3. Custom Reporting

**`custom/app/services/commmate/reports/custom_metrics_service.rb`**
```ruby
module Commmate
  module Reports
    class CustomMetricsService
      def initialize(account, date_range)
        @account = account
        @date_range = date_range
      end

      def generate
        {
          total_ai_responses: count_ai_responses,
          customer_satisfaction: calculate_csat,
          custom_metric: calculate_custom_metric
        }
      end

      private

      def count_ai_responses
        Message.where(account: @account)
               .where(message_type: :outgoing)
               .where(created_at: @date_range)
               .where("content_attributes->>'is_ai_generated' = ?", 'true')
               .count
      end

      def calculate_custom_metric
        # Your custom calculation
        0
      end
    end
  end
end
```

## Testing Custom Extensions

**`custom/spec/models/custom/account_spec.rb`**
```ruby
require 'rails_helper'

RSpec.describe 'Custom::Account' do
  let(:account) { create(:account) }

  describe '#commmate_subscription_status' do
    it 'returns free by default' do
      expect(account.commmate_subscription_status).to eq('free')
    end

    it 'returns custom status when set' do
      account.custom_attributes['commmate_subscription'] = 'premium'
      expect(account.commmate_subscription_status).to eq('premium')
    end
  end
end
```

## Troubleshooting

### Extension Not Loading

1. **Check the module naming**: Must be `Custom::ClassName`
2. **Check prepend_mod_with**: Ensure it's called at the bottom of the core file
3. **Restart the server**: Changes to custom/ require a restart
4. **Check logs**: Look for load errors in `log/development.log`

### Prepend Not Working

Add the prepend manually if it's missing:

```ruby
# At the bottom of app/models/conversation.rb
Conversation.prepend_mod_with('Conversation')
```

### Routes Not Loading

Ensure custom routes are loaded. Add to `config/application.rb`:

```ruby
# Load custom routes
config.paths['config/routes.rb'].concat Dir[Rails.root.join('custom/config/routes.rb')]
```

### Frontend Assets Not Compiling

Add custom JavaScript paths to `vite.config.ts`:

```javascript
resolve: {
  alias: {
    // ... existing aliases
    customDashboard: path.resolve(__dirname, 'custom/app/javascript/dashboard'),
  },
},
```

## Best Practices

1. **Always use namespaces**: Prefix with `Custom::` or `Commmate::`
2. **Document everything**: Add comments explaining why customizations exist
3. **Test thoroughly**: Write specs for custom functionality
4. **Check Enterprise**: Search `enterprise/` for similar patterns
5. **Keep it clean**: Remove unused custom code regularly
6. **Version control**: Track what upstream version your customizations are compatible with

## Maintenance Workflow

### Before Upstream Sync
```bash
# Document current state
git log --oneline custom/ > custom/CHANGELOG.md

# Note any modifications to core files
git diff upstream/develop -- app/ lib/ config/ > custom/core_changes.patch
```

### After Upstream Sync
```bash
# Test your custom extensions
bundle exec rspec custom/spec/
pnpm test

# Check for breaking changes
git diff HEAD~1 app/models/ app/services/
```

### Monthly Review
- Review custom/ for dead code
- Check if any customizations can be contributed upstream
- Update documentation
- Verify all tests pass

## Contributing Back to Chatwoot

If a customization might benefit the community:

1. Extract it from `custom/` to a new branch
2. Generalize the implementation
3. Add tests
4. Submit a PR to Chatwoot following their [contribution guidelines](https://www.chatwoot.com/docs/contributing-guide)

## Resources

- [Chatwoot Enterprise Development Guide](https://chatwoot.help/hc/handbook/articles/developing-enterprise-edition-features-38)
- [Ruby Modules: Include vs Prepend vs Extend](https://medium.com/@leo_hetsch/ruby-modules-include-vs-prepend-vs-extend-f09837a5b073)
- [Chatwoot API Documentation](https://www.chatwoot.com/developers/api/)

## Support

For CommMate-specific extension questions, contact the development team.

