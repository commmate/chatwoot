# CommMate Database Changes Guide

This guide documents how to properly handle database schema changes in the CommMate fork of Chatwoot.

## Overview

CommMate maintains its own database migrations that extend Chatwoot's schema. When making database changes, you must update both the migration file AND the schema.rb to ensure CI tests pass.

## How Rails Database Migrations Work

1. **Migration Files** (`db/migrate/*.rb`) - Define incremental database changes
2. **Schema File** (`db/schema.rb`) - Represents the current state of the database
3. **Schema Version** - The timestamp in `ActiveRecord::Schema.define(version: XXXXXXXXXX)` indicates the latest applied migration

### CI vs Production

| Environment | Database Setup | Notes |
|-------------|----------------|-------|
| **CI/Tests** | `db:schema:load` | Creates database from `schema.rb` (fast) |
| **Production** | `db:migrate` | Runs pending migrations (incremental) |
| **Development** | `db:migrate` or `db:schema:load` | Either works |

## Creating a New Migration

### Step 1: Generate the Migration

```bash
bundle exec rails generate migration AddFieldToTable field_name:type
```

Example:
```bash
bundle exec rails generate migration AddAvailableForCampaignsToLabels available_for_campaigns:boolean
```

### Step 2: Edit the Migration File

```ruby
# frozen_string_literal: true

# CommMate: Description of what this migration does
class AddAvailableForCampaignsToLabels < ActiveRecord::Migration[7.0]
  def change
    add_column :labels, :available_for_campaigns, :boolean, default: false, null: false
  end
end
```

**Important**: For boolean columns, always specify:
- `default: false` (or `true`)
- `null: false`

This avoids Rubocop's `Rails/ThreeStateBooleanColumn` warning.

### Step 3: Run the Migration Locally

```bash
bundle exec rails db:migrate
```

This updates your local database AND regenerates `db/schema.rb`.

### Step 4: Verify schema.rb Was Updated

Check that:
1. The new column appears in the table definition
2. The schema version at the top matches your migration timestamp

```ruby
# db/schema.rb
ActiveRecord::Schema[7.1].define(version: 2026_01_24_163545) do
  # ...
  create_table "labels", force: :cascade do |t|
    # ...
    t.boolean "available_for_campaigns", default: false, null: false
  end
end
```

### Step 5: Update Model (if needed)

If your migration adds a column, update the model's schema comment:

```ruby
# app/models/label.rb

# == Schema Information
# ...
#  available_for_campaigns :boolean          default(FALSE), not null
# ...
```

## Common Issues and Solutions

### Issue: "Migrations are pending" in CI

**Cause**: The schema version in `schema.rb` is older than your migration file timestamp.

**Solution**: Ensure the schema version matches or exceeds your latest migration:

```ruby
# Before (causes error)
ActiveRecord::Schema[7.1].define(version: 2026_01_16_100001) do

# After (fixed - matches migration 20260124163545)
ActiveRecord::Schema[7.1].define(version: 2026_01_24_163545) do
```

### Issue: Column exists in schema.rb but migration still runs

**Cause**: Migration timestamp is after the schema version.

**Solution**: After running `db:migrate` locally, commit the updated `schema.rb` with the new version.

### Issue: Rubocop complains about boolean column

**Error**: `Rails/ThreeStateBooleanColumn: Boolean columns should always have a default value and a NOT NULL constraint.`

**Solution**: Always define boolean columns with both `default` and `null: false`:

```ruby
# Wrong
add_column :table, :flag, :boolean

# Correct
add_column :table, :flag, :boolean, default: false, null: false
```

## Checklist for Database Changes

Before committing database changes, verify:

- [ ] Migration file exists in `db/migrate/`
- [ ] Migration file has `# frozen_string_literal: true` pragma
- [ ] Migration file has a CommMate comment explaining the purpose
- [ ] Boolean columns have `default` and `null: false`
- [ ] `db/schema.rb` includes the new column/table
- [ ] Schema version in `schema.rb` matches or exceeds migration timestamp
- [ ] Model schema comment is updated (if applicable)
- [ ] Ran `bundle exec rubocop db/migrate/your_migration.rb` to check for lint issues

## CommMate Migrations

Current CommMate-specific migrations:

| Migration | Description |
|-----------|-------------|
| `20260112140000_create_campaign_delivery_reports.rb` | Campaign delivery tracking |
| `20260115200000_create_inbox_migrations.rb` | Inbox migration feature |
| `20260116100001_migrate_custom_roles_to_access_permissions.rb` | Role permissions update |
| `20260124163545_add_available_for_campaigns_to_labels.rb` | Campaign label flag |

## Rolling Back Migrations

### In Development

```bash
# Rollback last migration
bundle exec rails db:rollback

# Rollback specific number of steps
bundle exec rails db:rollback STEP=3
```

### In Production

**Never delete migration files** that have been deployed to production. Instead:

1. Create a new migration to undo the changes
2. Or use `db:rollback` carefully on the production server

## Schema Conflicts When Merging Upstream

When merging from upstream Chatwoot:

1. **Schema conflicts** are common - Rails regenerates `schema.rb` on each migration
2. Accept upstream changes and then run `bundle exec rails db:migrate` locally
3. Commit the merged `schema.rb`

```bash
# After merge with conflicts in schema.rb
git checkout --theirs db/schema.rb  # Accept upstream
bundle exec rails db:migrate         # Apply our migrations
git add db/schema.rb                  # Commit updated schema
```

## References

- [Rails Migrations Guide](https://guides.rubyonrails.org/active_record_migrations.html)
- [Chatwoot Contributing Guide](https://www.chatwoot.com/docs/contributing-guide)
- [CommMate Core Modifications](./CORE-MODIFICATIONS.md)

