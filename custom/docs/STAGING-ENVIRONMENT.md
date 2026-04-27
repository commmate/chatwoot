# CommMate Staging Environment

**Purpose**: Test releases on staging before deploying to production  
**URL**: https://staging.commmate.com  
**Server**: 46.225.58.175 (Hetzner) — SSH alias `tutorialsbot`  
**Last Updated**: February 2026

---

## Overview

The staging environment mirrors production by restoring a daily Supabase backup into a local PostgreSQL database. It runs the `commmate/commmate:latest` Docker image and is accessible at `https://staging.commmate.com`.

**Architecture:**

```
┌──────────────────────────────────────────────────────┐
│  Hetzner Server (46.225.58.175)                      │
│                                                      │
│  /opt/traefik/          → Traefik reverse proxy      │
│  /opt/staging-commmate/ → CommMate staging stack     │
│                                                      │
│  ┌─────────┐   ┌───────────────┐   ┌──────────┐     │
│  │ Traefik │──▶│ stg-cm-rails  │──▶│ Postgres │     │
│  │ :80/443 │   │ :3000         │   │ (local)  │     │
│  └─────────┘   └───────────────┘   └──────────┘     │
│                │ stg-cm-sidekiq │   ┌──────────┐     │
│                └────────────────┘──▶│  Redis   │     │
│                                     └──────────┘     │
│                                                      │
│  Daily 3AM cron: Supabase backup → local restore     │
└──────────────────────────────────────────────────────┘
```

---

## Quick Reference

```bash
# SSH to staging server
ssh tutorialsbot

# Check staging status
cd /opt/staging-commmate
docker compose ps

# View logs
docker logs -f stg-cm-rails --tail 100

# Restart staging
docker compose restart rails sidekiq

# Update staging to latest image
docker compose pull && docker compose up -d rails sidekiq

# Run migrations
docker compose exec rails bundle exec rails db:migrate

# Rails console
docker compose exec rails bundle exec rails console
```

---

## Server Infrastructure

### SSH Access

```bash
# Uses SSH config alias (see ~/.ssh/config)
ssh tutorialsbot
# Resolves to: root@46.225.58.175 with key ~/.ssh/hetzner_ed25519
```

### Traefik (Reverse Proxy)

**Location**: `/opt/traefik/`

Handles SSL termination and routing via Docker labels. Uses Let's Encrypt for automatic TLS certificates.

- Network: `tutorialsbot-web` (external Docker network)
- Certificates stored in volume: `tutorialsbot-traefik-letsencrypt`
- HTTP → HTTPS redirect enabled

### CommMate Staging Stack

**Location**: `/opt/staging-commmate/`

```
/opt/staging-commmate/
├── docker-compose.yaml    # Service definitions
├── .env                   # Secrets and Supabase credentials
├── daily-restore.sh       # Cron script for DB restore
└── backups/               # Schema/data dumps and logs
    ├── schema.sql
    ├── data.sql
    ├── restore-YYYYMMDD.log
    └── cron.log
```

**Services:**

| Container | Image | Purpose |
|-----------|-------|---------|
| `stg-cm-rails` | `commmate/commmate:latest` | Web server (Puma) |
| `stg-cm-sidekiq` | `commmate/commmate:latest` | Background jobs |
| `stg-cm-postgres` | `pgvector/pgvector:pg16` | PostgreSQL with pgvector |
| `stg-cm-redis` | `redis:8-alpine` | Cache and job queues |

---

## Daily Database Restore

A cron job runs at **3:00 AM UTC** daily to refresh staging data from the Supabase production database.

**Crontab entry:**
```
0 3 * * * /opt/staging-commmate/daily-restore.sh >> /opt/staging-commmate/backups/cron.log 2>&1
```

**What the script does (7 steps):**

1. Dumps schema from Supabase using `supabase db dump`
2. Dumps data from Supabase using `supabase db dump --data-only --use-copy`
3. Stops `rails` and `sidekiq` containers
4. Drops and recreates `commmate_staging` database, adds extensions (`vector`, `pg_trgm`), sets `search_path` to `chatwoot, public`
5. Restores schema and data from dumps
6. Runs `rails db:migrate` (staging image may be ahead of production)
7. Restarts `rails` and `sidekiq` containers

**Logs**: `/opt/staging-commmate/backups/restore-YYYYMMDD.log` (kept for 7 days)

### Manual Restore

```bash
ssh tutorialsbot
/opt/staging-commmate/daily-restore.sh
```

### Restore Troubleshooting

**Migration fails on missing table:**
The staging image may have migrations for tables not yet in the production backup. The script uses `|| true` so migrations that fail are skipped. If a specific migration is critical, manually create the table:

```bash
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" stg-cm-postgres \
  psql -U postgres -d commmate_staging -c \
  "SET search_path TO chatwoot, public; CREATE TABLE IF NOT EXISTS table_name (id bigserial PRIMARY KEY, created_at timestamp, updated_at timestamp);"
```

---

## Deployment Workflow

### Standard Release (Build → Staging → Production)

**This is the required flow for all releases.**

```
1. Code changes on branch
        ↓
2. Build image: ./custom/script/build_multiplatform.sh vX.Y.Z
        ↓
3. Push to Docker Hub (version tag + latest)
        ↓
4. Deploy to STAGING (auto via :latest, or manual pull)
        ↓
5. Test on staging (manual or Playwright)
        ↓
6. Deploy to PRODUCTION (explicit version tag)
```

### Step 1: Update Staging

After pushing a new image to Docker Hub:

```bash
ssh tutorialsbot
cd /opt/staging-commmate

# Pull and restart with new image
docker compose pull
docker compose up -d rails sidekiq

# Run any new migrations
docker compose exec rails bundle exec rails db:migrate

# Verify
docker logs stg-cm-rails --tail 20
```

### Step 2: Test on Staging

Visit https://staging.commmate.com and verify:

- [ ] Login page loads with CommMate branding
- [ ] Dashboard and conversations work
- [ ] New feature/fix is visible and functional
- [ ] No console errors in browser dev tools
- [ ] Campaigns page renders correctly
- [ ] Settings pages load

**Staging test credentials:**
- Regular user: `schimuneck.matias@gmail.com` (from Supabase restore)
- Super Admin: `schimuneck.matias@gmail.com` at `/super_admin/sign_in`

### Step 3: Deploy to Production

Only after staging verification passes:

```bash
# See IMAGE-RELEASE.md and INSTALLATION.md for full production deployment steps
# Production is on a separate Supabase-backed server
```

---

## Updating the Staging Image

### When `latest` Tag Is Updated

Staging uses `commmate/commmate:latest`. After pushing a new `:latest` to Docker Hub:

```bash
ssh tutorialsbot
cd /opt/staging-commmate
docker compose pull
docker compose up -d rails sidekiq
docker compose exec rails bundle exec rails db:migrate
```

### When Testing a Specific Version

To temporarily pin staging to a specific version, edit the `docker-compose.yaml`:

```bash
ssh tutorialsbot
cd /opt/staging-commmate

# Edit image tag (both rails and sidekiq services)
sed -i 's|image: commmate/commmate:.*|image: commmate/commmate:v4.11.1.7|g' docker-compose.yaml

# Deploy
docker compose pull
docker compose up -d rails sidekiq
docker compose exec rails bundle exec rails db:migrate

# After testing, revert to :latest
sed -i 's|image: commmate/commmate:.*|image: commmate/commmate:latest|g' docker-compose.yaml
```

---

## Environment Details

### Key Environment Variables

| Variable | Value | Notes |
|----------|-------|-------|
| `FRONTEND_URL` | `https://staging.commmate.com` | |
| `DEFAULT_LOCALE` | `pt_BR` | |
| `DISABLE_CHATWOOT_CONNECTIONS` | `true` | Privacy |
| `SFTP_CAMPAIGNS_ENABLED` | `true` | |
| `RESEND_ENABLED` | `true` | |
| `ENABLE_ACCOUNT_SIGNUP` | `false` | |

### Database

- **Database name**: `commmate_staging`
- **Schema**: `chatwoot` (with `search_path` set to `chatwoot, public`)
- **Extensions**: `vector`, `pg_trgm`
- **Data source**: Daily Supabase production backup

### Network

- **External network**: `tutorialsbot-web` (shared with Traefik)
- **Internal network**: `stg-cm-internal` (database, Redis)

---

## Server Maintenance

### Disk Space

```bash
ssh tutorialsbot
df -h /
docker system df
```

**If low on space:**
```bash
docker system prune -f
docker image prune -a -f  # WARNING: removes all unused images
```

### Swap Memory

The server has a 2GB swap file at `/swapfile` to handle memory spikes during migrations and restores.

### Checking Cron Logs

```bash
ssh tutorialsbot
tail -50 /opt/staging-commmate/backups/cron.log
# Or check specific day's log
cat /opt/staging-commmate/backups/restore-20260228.log
```

---

## Related Documentation

- **Image Release**: `IMAGE-RELEASE.md` — Building and publishing Docker images
- **Installation**: `INSTALLATION.md` — Production setup and configuration
- **Upgrade Guide**: `UPGRADE.md` — Upgrading Chatwoot base version
- **Docker Setup**: `DOCKER-SETUP.md` — Local Docker development

---

**Last Updated**: February 28, 2026  
**Maintained By**: CommMate Team
