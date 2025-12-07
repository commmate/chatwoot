# CommMate Architecture & Code Organization

**Purpose**: Guide for developers (AI agents and humans) on where to place CommMate code  
**Goal**: Minimize conflicts with upstream Chatwoot while maintaining all CommMate features  
**Last Updated**: December 6, 2025

---

## 🎯 Core Principle: Embrace Merge Conflicts, Don't Hide Them

**Key Insight:** Merge conflicts are GOOD - they show you what changed upstream.  
File overrides are BAD - they silently ignore upstream improvements.

---

## 🚫 Critical Rule: NEVER Modify enterprise/ Folder

**IMPORTANT:** The `enterprise/` folder is managed by Chatwoot's Enterprise team and should NEVER be modified by CommMate.

**Why?**
- ❌ Enterprise code is maintained separately by Chatwoot
- ❌ We don't have visibility into their upgrade process
- ❌ Changes would be lost on Enterprise updates
- ❌ Could break Enterprise functionality
- ❌ Creates maintenance nightmares

**What to do instead:**
- ✅ Make changes in `app/` (core Chatwoot files)
- ✅ Enterprise will override our changes if they need to
- ✅ Let Enterprise handle their own folder
- ✅ Focus on OSS features that work with Enterprise

**This applies to:**
- `enterprise/app/` - NO modifications
- `enterprise/lib/` - NO modifications
- `enterprise/spec/` - NO modifications
- All other `enterprise/` subdirectories - NO modifications

**Exception:** None. If a feature needs Enterprise changes, request it from Chatwoot Enterprise team.

---

## 📁 Directory Structure

### custom/ - Configuration & Non-Code Only

```
custom/
├── config/                           # CommMate configuration
│   ├── branding.yml                 # Branding settings
│   ├── commmate_version.yml         # Version tracking
│   ├── installation_config.yml      # Installation defaults
│   ├── docker-entrypoint.sh         # Docker startup script
│   └── initializers/                # CommMate-specific initializers
│       ├── commmate_version.rb
│       ├── commmate_instance_status.rb
│       ├── commmate_config_overrides.rb
│       └── commmate_branding.rb
├── docs/                            # This documentation
│   ├── ARCHITECTURE.md             # This file
│   ├── REBRANDING.md
│   ├── DOWNSTREAM-RELEASE.md
│   ├── IMAGE-RELEASE.md
│   └── ...
├── locales/                         # CommMate translations
│   └── pt_BR.yml
├── scripts/                         # Build & deployment scripts
│   ├── build_multiplatform.sh
│   └── apply_commmate_branding.sh
├── styles/                          # CSS overrides
│   ├── variables.scss
│   └── branding.scss
└── assets/                          # Build-time assets (gitignored)
    ├── logos/
    └── favicons/
```

**Never put Ruby code in custom/** - it creates silent override problems.

---

## 📝 Where to Place CommMate Code

### Rule 1: NEW Features → Standard Rails Locations

**If the file/feature doesn't exist in Chatwoot, put it in standard Rails locations:**

```
app/
├── controllers/super_admin/
│   └── custom_roles_controller.rb          ✅ NEW (doesn't exist in Chatwoot)
├── dashboards/
│   └── custom_role_dashboard.rb             ✅ NEW (doesn't exist in Chatwoot)
├── fields/
│   └── permissions_field.rb                 ✅ NEW (doesn't exist in Chatwoot)
├── views/fields/permissions_field/
│   ├── _form.html.erb                       ✅ NEW (doesn't exist in Chatwoot)
│   ├── _index.html.erb                      ✅ NEW
│   └── _show.html.erb                       ✅ NEW
└── models/
    └── (CommMate models if any)             ✅ NEW features
```

**Why?**
- ✅ Zero conflict risk (Chatwoot doesn't have these files)
- ✅ Standard Rails structure
- ✅ Easy to contribute upstream if desired
- ✅ No autoload configuration needed
- ✅ Other developers understand immediately

**Commits clearly identify** these as CommMate additions via git history.

---

### Rule 2: Modifications → Modify in Place (Track with Git)

**If the file EXISTS in Chatwoot, modify it directly and let git track changes:**

```
app/
├── views/super_admin/application/
│   ├── _navigation.html.erb          ✅ MODIFY (change logo, version)
│   └── _icons.html.erb               ✅ MODIFY (add shield-check icon)
├── views/super_admin/devise/sessions/
│   └── new.html.erb                  ✅ MODIFY (CommMate logo)
├── dashboards/
│   └── account_user_dashboard.rb     ✅ MODIFY (add custom_role field)
├── policies/
│   └── campaign_policy.rb            ✅ MODIFY (add custom role check)
└── javascript/dashboard/
    ├── routes/.../campaigns.routes.js ✅ MODIFY (add campaign_manage)
    └── constants/permissions.js       ✅ MODIFY (add campaign_manage)
```

**Why Modify in Place?**
- ✅ **Git shows you conflicts** when Chatwoot updates these files
- ✅ **You review upstream changes** and merge them
- ✅ **You don't miss improvements** Chatwoot makes
- ✅ **Merge conflicts force you** to keep up to date
- ✅ **15-30 min per upgrade** vs hours tracking silent overrides

**Enterprise does this too** - they modify core files and handle merge conflicts.

---

### Rule 3: Extensions → Use Prepend Pattern (Advanced)

**For complex extensions to existing classes, use prepend modules:**

**Example: Extending a controller**

```ruby
# app/controllers/my_controller.rb (Chatwoot original - unchanged except last line)
class MyController < ApplicationController
  def index
    # ... Chatwoot code ...
  end
end

# At end of file:
MyController.prepend_mod_with('MyController') if defined?(prepend_mod_with)
```

**CommMate extension:**
```ruby
# app/controllers/commmate/my_controller.rb
module Commmate::MyController
  def index
    super # Call original
    # Add CommMate customization
  end
end
```

**Why Prepend?**
- ✅ Minimal change to core file (1 line)
- ✅ Extension code isolated in module
- ✅ Can override or extend methods
- ✅ Upstream updates to core file → you get them
- ✅ Only conflicts on the prepend line (trivial to resolve)

**When to use:**
- Extending existing controllers with complex logic
- Modifying models with additional behavior
- Adding hooks to existing services

**When NOT to use:**
- NEW features (just create new file)
- Simple 1-3 line changes (modify in place)

---

## ⚠️ Anti-Patterns: What NOT to Do

### ❌ DON'T: Override Files in custom/app/

```
# BAD:
custom/app/views/super_admin/_navigation.html.erb  ← Complete override
```

**Problem:**
- Chatwoot updates _navigation.html.erb in v4.9.0
- Your custom/ version doesn't have those updates
- You never know what you're missing
- Silent failure

**Instead:** Modify `app/views/super_admin/_navigation.html.erb` directly  
**Result:** Git conflict in v4.9.0 → you see what changed → you merge

---

### ❌ DON'T: Duplicate Files

```
# BAD:
app/dashboards/account_user_dashboard.rb          ← Chatwoot original
custom/app/dashboards/account_user_dashboard.rb   ← CommMate version
```

**Problem:**
- Which one does Rails load?
- Confusion about source of truth
- Merge conflicts in wrong file

**Instead:** Pick one location and use prepend if needed

---

### ❌ DON'T: Abstract Too Early

```
# BAD:
custom/app/helpers/commmate_branding_helper.rb
# Then use helpers in views that fail to load
```

**Problem:**
- Helper not in view context
- Autoload issues
- Over-engineering

**Instead:** Use hardcoded values or simple erb expressions  
**Example:** `<%= defined?(COMMMATE_VERSION) ? COMMMATE_VERSION : Chatwoot.config[:version] %>`

---

## ✅ Best Practices

### 1. Keep Changes Small and Focused

**Good:**
```ruby
# app/policies/campaign_policy.rb
def index?
  @account_user.administrator? || 
  @account_user.custom_role&.permissions&.include?('campaign_manage')
end
```

**Why:** Clear, minimal, easy to merge with upstream changes.

---

### 2. Use Git Commits to Document

```bash
git commit -m "feat(admin): add campaign_manage permission check to CampaignPolicy

Allows users with custom role containing campaign_manage permission
to access campaign features.

Modified: app/policies/campaign_policy.rb
"
```

**Why:** Future you (or agents) can see why changes were made.

---

### 3. Comment CommMate-Specific Code

```ruby
# CommMate: Add custom role permission check
def index?
  @account_user.administrator? || 
  @account_user.custom_role&.permissions&.include?('campaign_manage')
end
```

**Why:** During merge conflicts, you know this is intentional.

---

### 4. Document All Core Modifications

Maintain a list in `custom/docs/CORE-MODIFICATIONS.md`:
- Which files modified
- Why modified
- What changes were made
- When to review during upgrades

---

## 📋 Current CommMate Modifications

### Files Modified in Core (Accept merge conflicts):

**Total: ~12 files with small changes**

1. **config/routes.rb** (1 line)
   - `resources :custom_roles`

2. **config/initializers/git_sha.rb** (~15 lines)
   - CommMate git SHA tracking

3. **enterprise/app/models/custom_role.rb** (2 lines)
   - `campaign_manage` permission
   - Uniqueness validation

4. **app/policies/campaign_policy.rb** (~10 lines)
   - Custom role permission check

5. **app/dashboards/account_user_dashboard.rb** (3 lines)
   - Added `custom_role` field to ATTRIBUTE_TYPES
   - Added to COLLECTION_ATTRIBUTES
   - Added to SHOW_PAGE_ATTRIBUTES

6. **app/views/super_admin/application/_navigation.html.erb** (~5 lines)
   - CommMate logo (PNG instead of SVG)
   - CommMate version display
   - CommMate branding text

7. **app/views/super_admin/application/_icons.html.erb** (3 lines)
   - Added shield-check-line icon SVG

8. **app/views/super_admin/devise/sessions/new.html.erb** (3 lines)
   - Title: SuperAdmin | CommMate
   - Logo: CommMate PNG

9. **app/javascript/dashboard/routes/dashboard/campaigns/campaigns.routes.js** (1 line)
   - Added campaign_manage to permissions array

10. **app/javascript/dashboard/constants/permissions.js** (1 line)
    - Added campaign_manage

11. **app/javascript/dashboard/i18n/locale/en/customRole.json** (1 line)
    - CAMPAIGN_MANAGE translation

12. **docker/Dockerfile.commmate** (~20 lines)
    - CommMate build steps

**Total Changes:** ~65 lines across 12 files = Very maintainable

---

### Files 100% CommMate (No conflicts possible):

**In app/ (NEW features):**
- `app/controllers/super_admin/custom_roles_controller.rb`
- `app/dashboards/custom_role_dashboard.rb`
- `app/fields/permissions_field.rb`
- `app/views/fields/permissions_field/*`

**In custom/ (Config & Docs):**
- `custom/config/commmate_version.yml`
- `custom/config/initializers/*`
- `custom/docs/*`
- `custom/locales/*`
- `custom/styles/*`
- `custom/scripts/*`

**In db/migrate/ (CommMate migrations):**
- `db/migrate/*commmate*.rb`
- `db/migrate/20251202140000_add_campaign_manage_to_manager_roles.rb`

---

## 🔄 Upgrade Process (Downstream from Chatwoot)

### When New Chatwoot Version Releases:

**Step 1: Create downstream branch**
```bash
git checkout -b downstream/v4.9.0
git pull upstream release/4.9.0
git push origin downstream/v4.9.0
```

**Step 2: Merge into CommMate**
```bash
git checkout -b commmate/v4.9.0
git merge downstream/v4.9.0
```

**Step 3: Resolve Conflicts**

Git will show conflicts in ~10-12 files. For each:

```
<<<<<<< HEAD (CommMate)
  @account_user.administrator? || 
  @account_user.custom_role&.permissions&.include?('campaign_manage')
=======
  @account_user.administrator? && new_chatwoot_condition
>>>>>>> downstream/v4.9.0
```

**Resolution:**
```ruby
# Keep both conditions
@account_user.administrator? && new_chatwoot_condition ||
@account_user.custom_role&.permissions&.include?('campaign_manage')
```

**Step 4: Test**
```bash
bundle install
pnpm install
bin/rails db:migrate
bin/rails s
# Test all CommMate features
```

**Step 5: Merge to main**
```bash
git checkout main
git merge commmate/v4.9.0
git push origin main
```

**Estimated Time:** 30-60 minutes (most conflicts are trivial)

---

## 🚫 What NOT to Put in custom/

### Never in custom/app/:
- ❌ Controllers (unless testing - move to app/ when ready)
- ❌ Models (can't override properly)
- ❌ Dashboards (Administrate doesn't check custom/)
- ❌ Fields (Administrate doesn't check custom/)
- ❌ Helpers (view context issues)
- ❌ Services that override existing ones

### Why?
These create "shadow copies" that silently ignore upstream updates.

---

## ✅ What to Put in custom/

### Only Configuration & Documentation:

**custom/config/:**
- YAML configuration files
- Docker entrypoint scripts
- CommMate initializers (loaded via config/initializers/)

**custom/docs/:**
- All markdown documentation
- Architecture guides
- Process documentation

**custom/locales/:**
- pt_BR translations
- Language overrides

**custom/styles/:**
- SCSS variable overrides
- CSS customizations (loaded via app.scss import)

**custom/scripts/:**
- Build scripts (build_multiplatform.sh)
- Deployment automation
- Utility scripts

**custom/spec/:**
- Specs for CommMate-only features
- Integration tests specific to CommMate

---

## 🔧 How to Add New CommMate Features

### Scenario 1: Completely New Feature

**Example:** Adding custom roles management

**Do:**
```ruby
# app/controllers/super_admin/custom_roles_controller.rb (NEW file)
class SuperAdmin::CustomRolesController < SuperAdmin::ApplicationController
  # ... CommMate feature ...
end

# app/dashboards/custom_role_dashboard.rb (NEW file)
class CustomRoleDashboard < Administrate::BaseDashboard
  # ... CommMate dashboard ...
end

# config/routes.rb (ADD 1 line)
resources :custom_roles, only: [:index, :new, :create, :show, :edit, :update, :destroy]
```

**Result:** Clear, tracked by git, no conflicts

---

### Scenario 2: Extending Existing Feature

**Example:** Adding custom_role field to AccountUser

**Option A: Direct Modification (Recommended for small changes)**
```ruby
# app/dashboards/account_user_dashboard.rb (MODIFY existing file)
ATTRIBUTE_TYPES = {
  # ... existing fields ...
  custom_role: Field::BelongsTo.with_options(class_name: 'CustomRole'), # ← ADD
}

SHOW_PAGE_ATTRIBUTES = %i[
  # ... existing ...
  custom_role  # ← ADD
]
```

**Commit message:**
```
feat(admin): display custom role in account user dashboard

Modified: app/dashboards/account_user_dashboard.rb
Added custom_role field to show user's assigned role
```

**Option B: Prepend Pattern (For complex extensions)**
```ruby
# app/dashboards/account_user_dashboard.rb (ADD 1 line at end)
AccountUserDashboard.prepend_mod_with('AccountUserDashboard') if defined?(prepend_mod_with)

# app/dashboards/commmate/account_user_dashboard.rb (NEW file)
module Commmate::AccountUserDashboard
  def self.prepended(base)
    base::ATTRIBUTE_TYPES[:custom_role] = Field::BelongsTo.with_options(class_name: 'CustomRole')
    base::SHOW_PAGE_ATTRIBUTES.insert(5, :custom_role)
  end
end
```

**Use prepend when:**
- Changes are complex (>10 lines)
- You might want to disable easily
- Logic is isolated

**Use direct modification when:**
- Changes are simple (<10 lines)
- Tightly integrated with core
- Low complexity

---

### Scenario 3: Branding/UI Changes

**Example:** Super admin navigation branding

**Do:**
```html
<!-- app/views/super_admin/application/_navigation.html.erb -->
<!-- MODIFY directly - change Chatwoot → CommMate -->
<div class="text-sm">CommMate <%= defined?(COMMMATE_VERSION) ? COMMMATE_VERSION : Chatwoot.config[:version] %></div>
```

**Why not override in custom/?**
- If Chatwoot improves navigation UI, you want those updates
- Git conflict shows you what changed
- Easy to merge: keep Chatwoot structure + your branding

---

## 🎨 Special Case: CSS & Assets

### CSS Overrides - Use custom/styles/

**This is one area where overrides work well:**

```scss
// custom/styles/variables.scss
$brand-color: #107e44;  // CommMate green instead of Chatwoot blue

// custom/styles/branding.scss
.brand-element {
  color: $brand-color;
}
```

**Loaded via:**
```scss
// app/javascript/dashboard/assets/scss/app.scss (ADD at end)
@import '../../../../../custom/styles/variables';
@import '../../../../../custom/styles/branding';
```

**Why this works:**
- CSS is additive - your rules cascade over Chatwoot's
- Color changes are safe overrides
- Low conflict risk

---

## 📊 Summary Table

| Type | Location | Reason | Conflicts? |
|------|----------|--------|------------|
| **NEW controllers** | `app/controllers/` | Standard Rails | Never |
| **NEW dashboards** | `app/dashboards/` | Standard Rails | Never |
| **NEW fields** | `app/fields/` | Standard Rails | Never |
| **NEW views** | `app/views/` | Standard Rails | Never |
| **NEW models** | `app/models/` | Standard Rails | Never |
| **Modified views** | `app/views/` (in place) | Git tracks | Rare, easy |
| **Modified dashboards** | `app/views/` (in place) | Git tracks | Rare, easy |
| **Modified policies** | `app/policies/` (in place) | Git tracks | Rare, easy |
| **Modified routes** | `config/routes.rb` | Required location | Rare, easy |
| **Modified JS** | `app/javascript/` (in place) | Git tracks | Medium |
| **Config** | `custom/config/` | CommMate-only | Never |
| **Docs** | `custom/docs/` | CommMate-only | Never |
| **Scripts** | `custom/scripts/` | CommMate-only | Never |
| **Styles** | `custom/styles/` | Cascade override | Never |
| **Migrations** | `db/migrate/` | Standard Rails | Never |
| **Initializers** | `custom/config/initializers/` | Loaded by Rails | Never |

---

## 🔍 How to Check: "Should This Go in custom/?"

### Decision Tree:

**1. Is it a configuration file, doc, or script?**
- YES → `custom/config/`, `custom/docs/`, or `custom/scripts/`
- NO → Continue to #2

**2. Is it CSS/SCSS styling?**
- YES → `custom/styles/`
- NO → Continue to #3

**3. Is it a completely NEW file (doesn't exist in Chatwoot)?**
- YES → Standard Rails location (`app/controllers/`, `app/models/`, etc.)
- NO → Continue to #4

**4. Is it modifying an existing Chatwoot file?**
- YES → Modify in place, git will track it
- Use prepend pattern if changes are complex (>10 lines)

---

## 🚀 Contribution Strategy

### If You Want to Contribute a Feature Upstream:

**Because code is in standard locations:**

1. Create a branch from Chatwoot upstream
2. Cherry-pick your feature commits
3. Remove CommMate branding (git revert specific lines)
4. Submit PR to Chatwoot

**Example:**
```bash
git checkout -b feature/custom-roles-upstream upstream/develop
git cherry-pick <your-custom-roles-commits>
# Edit to remove CommMate-specific parts
git push fork feature/custom-roles-upstream
# Create PR
```

**This is easy because** files are already in standard Rails locations.

---

## 📝 Maintenance Checklist

### Before Each Chatwoot Upgrade:

- [ ] Review `custom/docs/CORE-MODIFICATIONS.md` (list of modified files)
- [ ] Check Chatwoot release notes for changes to those files
- [ ] Prepare to merge conflicts in ~10-12 files
- [ ] Test all CommMate features after merge

### During Upgrade:

- [ ] Create downstream branch from upstream
- [ ] Merge into commmate/vX.Y.Z branch
- [ ] Resolve conflicts (git shows you exactly what changed)
- [ ] Run migrations
- [ ] Test super admin, custom roles, branding
- [ ] Merge to main

### After Upgrade:

- [ ] Update `custom/docs/CORE-MODIFICATIONS.md` if new files added
- [ ] Update version in `custom/config/commmate_version.yml`
- [ ] Build and test Docker image
- [ ] Deploy

**Estimated time per upgrade:** 1-2 hours (mostly testing)

---

## 🎓 Learning from Enterprise Edition

Chatwoot Enterprise modifies ~100 core files directly and handles upgrades successfully.

**Their strategy:**
- Modify core files in place
- Use prepend for complex extensions
- Handle merge conflicts
- Document changes

**We should do the same** with our ~12 file modifications.

---

## 🏆 Final Architecture

```
chatwoot/
├── app/                                    # Chatwoot + CommMate code
│   ├── controllers/super_admin/
│   │   ├── custom_roles_controller.rb     # NEW (CommMate)
│   │   └── instance_statuses_controller.rb # MODIFIED (CommMate extension)
│   ├── dashboards/
│   │   ├── custom_role_dashboard.rb       # NEW (CommMate)
│   │   └── account_user_dashboard.rb      # MODIFIED (+custom_role field)
│   ├── fields/
│   │   └── permissions_field.rb           # NEW (CommMate)
│   ├── views/
│   │   ├── super_admin/                   # MODIFIED (CommMate branding)
│   │   └── fields/permissions_field/      # NEW (CommMate)
│   └── policies/
│       └── campaign_policy.rb             # MODIFIED (custom role check)
├── custom/                                 # CommMate config & docs ONLY
│   ├── config/                            # Configuration
│   ├── docs/                              # Documentation (this file!)
│   ├── locales/                           # Translations
│   ├── scripts/                           # Build scripts
│   └── styles/                            # CSS overrides
├── db/migrate/                            # All migrations
│   └── *commmate*.rb                      # CommMate migrations
└── docker/
    └── Dockerfile.commmate                # CommMate Docker build

```

**Clean, maintainable, upgrade-friendly.** ✅

---

## 📚 Related Documentation

- `DOWNSTREAM-RELEASE.md` - How to merge new Chatwoot versions
- `IMAGE-RELEASE.md` - How to build CommMate Docker images
- `REBRANDING.md` - CommMate branding system
- `USER-ROLES.md` - Custom roles feature documentation
- `CORE-MODIFICATIONS.md` - Complete list of modified core files

---

**Last Updated:** December 6, 2025  
**CommMate Version:** v4.8.0.1  
**Base Chatwoot:** v4.8.0

**This document is the source of truth for CommMate architecture decisions.**

