# CommMate Deployment Workflow

**Purpose**: End-to-end deployment process — staging is mandatory before production  
**Golden Rule**: **Never deploy directly to production. Always test on staging first.**  
**Last Updated**: February 2026

---

## Quick Reference

```
Code → Build → Push → Staging → Test → Production
```

| Step | Command | Where |
|------|---------|-------|
| 1. Version bump | Edit `custom/config/commmate_version.yml` | Local |
| 2. Commit & push | `git push origin commmate/vX.Y.Z` | Local |
| 3. Build image | `./custom/script/build_multiplatform.sh vX.Y.Z` | Local |
| 4. Push to Hub | `podman manifest push ...` (version + latest) | Local |
| 5. Deploy staging | `ssh tutorialsbot` → pull + restart | Staging |
| 6. Test staging | Browser/Playwright at staging.commmate.com | Staging |
| 7. Deploy production | Explicit version tag on production server | Production |

---

## Infrastructure

| Environment | URL | Server | Image Tag |
|-------------|-----|--------|-----------|
| **Staging** | https://staging.commmate.com | 46.225.58.175 (SSH: `tutorialsbot`) | `commmate/commmate:latest` |
| **Production** | Supabase-backed (managed separately) | — | `commmate/commmate:vX.Y.Z` (pinned) |

**Key difference**: Staging uses `:latest` (auto-updates on pull). Production uses pinned version tags (explicit updates only).

---

## Step-by-Step Deployment

### Step 1: Build and Push Image

Follow `IMAGE-RELEASE.md` for the full build process. Summary:

```bash
cd /Users/schimuneck/projects/commmmate/chatwoot

# Bump version
# Edit custom/config/commmate_version.yml

# Commit and push
git add -A && git commit -m "chore: bump version to vX.Y.Z"
git push origin commmate/vX.Y.Z

# Build multi-platform image
./custom/script/build_multiplatform.sh vX.Y.Z

# Push to Docker Hub
podman manifest push commmate/commmate:vX.Y.Z docker://commmate/commmate:vX.Y.Z
podman manifest push commmate/commmate:vX.Y.Z docker://commmate/commmate:latest
```

### Step 2: Deploy to Staging (MANDATORY)

```bash
ssh tutorialsbot
cd /opt/staging-commmate

# Pull latest image
docker compose pull

# Restart app containers
docker compose up -d rails sidekiq

# Run migrations
docker compose exec rails bundle exec rails db:migrate

# Verify startup
docker logs stg-cm-rails --tail 30
```

### Step 3: Test on Staging (MANDATORY)

**Minimum verification checklist** — all must pass before production:

- [ ] Login page loads at https://staging.commmate.com/app/login
- [ ] CommMate branding visible (green theme, logo, title)
- [ ] Dashboard loads with conversations
- [ ] The specific feature/fix being released works correctly
- [ ] No JavaScript console errors on key pages
- [ ] Settings pages render (Inboxes, Account)
- [ ] Campaigns page renders (if campaigns-related change)

**Test credentials:**
- Regular: `schimuneck.matias@gmail.com` (from daily Supabase restore)
- Super Admin: `schimuneck.matias@gmail.com` at `/super_admin/sign_in`

**Optional: Playwright automated test** (recommended for larger releases):
```
Run Playwright against https://staging.commmate.com
```

### Step 4: Deploy to Production (only after staging passes)

Production deployment uses an explicit, pinned version tag — never `:latest`.

```bash
# SSH to production server
# Update docker-compose.yaml to use the new version tag
# Pull and restart

docker compose pull
docker compose up -d chatwoot sidekiq
docker compose exec chatwoot bundle exec rails db:migrate
```

See `INSTALLATION.md` for full production deployment details.

---

## Daily Staging Refresh

Staging database is automatically restored from the Supabase production backup at **3:00 AM UTC** daily.

- Script: `/opt/staging-commmate/daily-restore.sh`
- Logs: `/opt/staging-commmate/backups/restore-YYYYMMDD.log`
- Cron log: `/opt/staging-commmate/backups/cron.log`

This means staging always has fresh production data for realistic testing.

See `STAGING-ENVIRONMENT.md` for full infrastructure details.

---

## Rollback

### Staging Rollback

```bash
ssh tutorialsbot
cd /opt/staging-commmate

# Pin to previous version
sed -i 's|image: commmate/commmate:.*|image: commmate/commmate:vPREVIOUS|g' docker-compose.yaml
docker compose pull && docker compose up -d rails sidekiq

# Revert to :latest when done
sed -i 's|image: commmate/commmate:.*|image: commmate/commmate:latest|g' docker-compose.yaml
```

### Production Rollback

```bash
# Update docker-compose to previous version tag
# Pull and restart
docker compose pull && docker compose up -d chatwoot sidekiq
```

---

## Hotfix Process

For urgent production fixes that cannot wait for full staging validation:

1. Fix the code, commit, build image with a new patch version
2. Deploy to staging and do a **focused test** on the specific fix
3. Deploy to production immediately after staging confirms the fix
4. Document the hotfix in the commit message: `fix(scope): urgent description`

Even hotfixes go through staging — just with a shorter test cycle focused on the fix.

---

## Related Documentation

| Doc | Purpose |
|-----|---------|
| `IMAGE-RELEASE.md` | Building and publishing Docker images |
| `STAGING-ENVIRONMENT.md` | Staging server setup, daily restore, infrastructure |
| `INSTALLATION.md` | Production setup and configuration |
| `DOWNSTREAM-RELEASE.md` | Creating release branches from upstream Chatwoot |

---

**Last Updated**: February 28, 2026  
**Maintained By**: CommMate Team
