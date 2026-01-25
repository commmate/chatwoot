# CommMate Development Guidelines

**Purpose:** Development best practices and common pitfalls for CommMate code  
**Goal:** Prevent repeated issues and maintain code quality  
**Last Updated:** January 25, 2026

---

## 📋 Table of Contents

1. [Ruby/Rails Best Practices](#ruby-rails-best-practices)
2. [Rubocop Common Issues](#rubocop-common-issues)
3. [Testing Guidelines](#testing-guidelines)
4. [CI/CD Considerations](#ci-cd-considerations)

---

## Ruby/Rails Best Practices

### Module Definition for Compact Class Syntax

When using compact class syntax (e.g., `class CommMate::Branding`), the parent module **must be defined first**:

```ruby
# ❌ WRONG - Will cause "uninitialized constant CommMate" error
class CommMate::Branding
  # ...
end

# ✅ CORRECT - Define the module first
module CommMate; end

class CommMate::Branding
  # ...
end
```

**Why:** Ruby's compact notation assumes the parent constant already exists. In initializers especially, this can cause load order issues.

### Concerns for Code Organization

Extract shared functionality into concerns to:
- Reduce class/module length
- Improve testability
- Enable code reuse

**Location:** `app/controllers/concerns/` for controller helpers

Example structure for Evolution API:
```
app/controllers/concerns/
├── evolution_url_helper.rb      # URL handling for containerized Evolution
├── evolution_inbox_helper.rb    # Common inbox validation/utilities
└── evolution_phone_helper.rb    # Phone number extraction/formatting
```

---

## Rubocop Common Issues

### 1. Missing `rubocop:enable` Directive

When disabling cops, **always add the enable directive**:

```ruby
# ❌ WRONG - Missing enable directive
# rubocop:disable Metrics/AbcSize
def complex_method
  # ...
end

# ✅ CORRECT - Always re-enable
# rubocop:disable Metrics/AbcSize
def complex_method
  # ...
end
# rubocop:enable Metrics/AbcSize
```

### 2. Trailing Empty Lines

Rubocop requires exactly one newline at end of file, no trailing blank lines:

```ruby
# ❌ WRONG - Extra blank line at end
end

# (blank line here)

# ✅ CORRECT - Single newline at end
end
```

### 3. Rescue Modifier Style

Avoid rescue in modifier form for complex error handling:

```ruby
# ❌ WRONG - Rescue modifier
value = object.method rescue 'default'

# ✅ CORRECT - Use respond_to? or begin/rescue
value = object.respond_to?(:method) ? object.method : 'default'

# Or for more complex cases:
begin
  value = object.method
rescue SomeError
  value = 'default'
end
```

### 4. Rails/Blank Preference

Use `blank?` instead of `!present?`:

```ruby
# ❌ WRONG
next unless value.present?

# ✅ CORRECT  
next if value.blank?
```

### 5. Block/Class Length Limits

When blocks or classes exceed limits:
- **Block limit:** 30 lines
- **Class limit:** 175 lines
- **Module limit:** 100 lines

**Solutions:**
1. Extract logic into helper methods
2. Create service objects
3. Use concerns for controllers
4. Create modules with class methods for initializers

Example - Refactoring a long initializer block:

```ruby
# ❌ WRONG - Block too long (>30 lines)
Rails.application.config.after_initialize do
  # 40 lines of code...
end

# ✅ CORRECT - Extract to module
module MyConfigHelper
  class << self
    def apply_config
      # Logic here...
    end
  end
end

Rails.application.config.after_initialize do
  MyConfigHelper.apply_config
end
```

### 6. Perceived Complexity

When methods have too many branches:

```ruby
# ❌ WRONG - Too complex
def chatwoot_reachable_url
  if Rails.env.development?
    frontend_url = ENV.fetch('FRONTEND_URL', nil)
    if frontend_url&.include?('localhost') || frontend_url&.include?('127.0.0.1')
      host_ip = `ipconfig getifaddr en0 2>/dev/null`.strip
      host_ip = '192.168.0.22' if host_ip.blank?
      "http://#{host_ip}:3000"
    else
      frontend_url
    end
  else
    ENV.fetch('FRONTEND_URL', nil) || Rails.application.routes.url_helpers.root_url
  end
end

# ✅ CORRECT - Extract helper methods
def chatwoot_reachable_url
  return production_frontend_url unless Rails.env.development?
  development_frontend_url
end

def production_frontend_url
  ENV.fetch('FRONTEND_URL', nil) || Rails.application.routes.url_helpers.root_url
end

def development_frontend_url
  frontend_url = ENV.fetch('FRONTEND_URL', nil)
  return frontend_url unless localhost_url?(frontend_url)
  "http://#{development_host_ip}:3000"
end

def localhost_url?(url)
  url&.include?('localhost') || url&.include?('127.0.0.1')
end

def development_host_ip
  host_ip = `ipconfig getifaddr en0 2>/dev/null`.strip
  host_ip.presence || '192.168.0.22'
end
```

---

## Testing Guidelines

### Running CommMate-Specific Tests

```bash
# Contact Preferences tests
bundle exec rspec spec/services/contact_preference_token_service_spec.rb
bundle exec rspec spec/drops/contact_drop_spec.rb
bundle exec rspec spec/models/label_spec.rb

# Run all at once
bundle exec rspec spec/services/contact_preference_token_service_spec.rb \
  spec/drops/contact_drop_spec.rb \
  spec/models/label_spec.rb
```

### Verifying CommMate Components

Run this to verify all components are working:

```bash
bundle exec rails runner "
puts 'Testing CommMate components...'
puts 'CommMate::Branding: ' + (defined?(CommMate::Branding) ? 'OK' : 'FAILED')
puts 'EvolutionApi::Client: ' + (defined?(EvolutionApi::Client) ? 'OK' : 'FAILED')
puts 'ContactPreferenceTokenService: ' + (defined?(ContactPreferenceTokenService) ? 'OK' : 'FAILED')
puts 'Label.campaign_labels: ' + (Label.respond_to?(:campaign_labels) ? 'OK' : 'FAILED')
"
```

---

## CI/CD Considerations

### GitHub Actions Workflow Inputs

When using GitHub Actions, ensure correct inputs for each action:

```yaml
# ❌ WRONG - These are checkout inputs, not pnpm inputs
- uses: pnpm/action-setup@v4
  with:
    ref: ${{ github.event.pull_request.head.ref }}      # WRONG
    repository: ${{ github.event.pull_request.head.repo.full_name }}  # WRONG

# ✅ CORRECT - pnpm/action-setup only accepts these inputs
- uses: pnpm/action-setup@v4
  # No ref/repository inputs - those are for actions/checkout
```

### Database Schema Triggers

When using `db:schema:load` in CI, ensure `schema.rb` includes database triggers:

```ruby
# Required triggers for display_id sequences
create_trigger("accounts_after_insert_row_tr", :generated => true, :compatibility => 1)
  .on("accounts")
  .after(:insert)
  .for_each(:row) do
  "execute format('create sequence IF NOT EXISTS conv_dpid_seq_%s', NEW.id);"
end

create_trigger("conversations_before_insert_row_tr", :generated => true, :compatibility => 1)
  .on("conversations")
  .before(:insert)
  .for_each(:row) do
  "NEW.display_id := nextval('conv_dpid_seq_' || NEW.account_id);"
end
```

### Files to Ignore

Add CommMate-specific local files to `.gitignore`:

```gitignore
# CommMate local environment
commmate.env
```

---

## Quick Reference

| Issue | Solution |
|-------|----------|
| `uninitialized constant CommMate` | Add `module CommMate; end` before class |
| Missing rubocop:enable | Add enable directive after disabled block |
| Trailing blank lines | Remove extra blank lines at file end |
| Rescue modifier style | Use `respond_to?` or begin/rescue block |
| `!present?` usage | Use `blank?` instead |
| Block too long | Extract to helper module/methods |
| Class too long | Extract to concerns |
| Method too complex | Extract helper methods |
| pnpm action inputs | Don't pass ref/repository to pnpm/action-setup |
| display_id NULL errors | Ensure schema.rb has trigger definitions |

---

## Related Documentation

- [CORE-MODIFICATIONS.md](./CORE-MODIFICATIONS.md) - List of modified Chatwoot files
- [CONTACT-PREFERENCES.md](./CONTACT-PREFERENCES.md) - Contact preferences feature docs
- [DATABASE-CHANGES.md](./DATABASE-CHANGES.md) - Database schema changes
- [Chatwoot CLAUDE.md](../../CLAUDE.md) - General development guidelines

