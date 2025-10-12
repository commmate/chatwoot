# CommMate Chatwoot Deployment Guide

## Quick Start

Your custom Chatwoot image with CommMate extensions is ready to deploy!

**Image:** `chatwoot:commmate-dev`  
**Docker Compose:** `docker-compose.commmate.yaml`

## 🚀 Deployment Steps

### 1. Create Environment File

Create `.env.commmate` in the project root:

```bash
cp custom/env.template .env.commmate
```

Or create it manually with this content:

```bash
# Database
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DATABASE=chatwoot_commmate
POSTGRES_USERNAME=postgres
POSTGRES_PASSWORD=postgres_password_change_me

# Redis
REDIS_URL=redis://redis:6379
REDIS_PASSWORD=redis_password_change_me

# Rails - REPLACE SECRET_KEY_BASE
SECRET_KEY_BASE=b7d7dd3fb6ed4f1829dcb2f7d21c6efbeca45762f97480c5ae74c98fab5f8225df2572693173c5dd6a6cae58c9389c57638cdcc8cb9438f8ebf955d9950f3e4a
FRONTEND_URL=http://localhost:3000
RAILS_ENV=development

# CommMate Features
COMMMATE_ENABLED=true
COMMMATE_KANBAN_ENABLED=true

# Storage
ACTIVE_STORAGE_SERVICE=local
```

### 2. Start Services

```bash
# Using Podman
podman-compose -f docker-compose.commmate.yaml up -d

# Or using Docker
docker-compose -f docker-compose.commmate.yaml up -d
```

### 3. Initialize Database

```bash
# Create database
podman-compose -f docker-compose.commmate.yaml exec rails bundle exec rails db:create

# Load schema
podman-compose -f docker-compose.commmate.yaml exec rails bundle exec rails db:schema:load

# Seed data (creates admin user)
podman-compose -f docker-compose.commmate.yaml exec rails bundle exec rails db:seed
```

### 4. Access Chatwoot

Open http://localhost:3000

**Default Credentials** (from seed):
- Email: (check the seed output)
- Password: (check the seed output)

## 📋 Useful Commands

### Service Management

```bash
# View logs
podman-compose -f docker-compose.commmate.yaml logs -f

# View specific service logs
podman-compose -f docker-compose.commmate.yaml logs -f rails
podman-compose -f docker-compose.commmate.yaml logs -f sidekiq

# Restart services
podman-compose -f docker-compose.commmate.yaml restart

# Stop services
podman-compose -f docker-compose.commmate.yaml down

# Stop and remove volumes (⚠️ DELETES DATA)
podman-compose -f docker-compose.commmate.yaml down -v
```

### Rails Commands

```bash
# Rails console
podman-compose -f docker-compose.commmate.yaml exec rails bundle exec rails console

# Run migrations
podman-compose -f docker-compose.commmate.yaml exec rails bundle exec rails db:migrate

# Create admin user manually
podman-compose -f docker-compose.commmate.yaml exec rails bundle exec rails runner "
user = User.create!(
  name: 'Admin',
  email: 'admin@commmate.com',
  password: 'Password123!',
  password_confirmation: 'Password123!'
);
account = Account.create!(name: 'CommMate');
AccountUser.create!(account: account, user: user, role: :administrator)
"

# Check custom directory is loaded
podman-compose -f docker-compose.commmate.yaml exec rails ls -la /app/custom
```

### Development Workflow

```bash
# After changing code, rebuild image
podman build --build-arg RAILS_ENV=development --build-arg BUNDLE_WITHOUT="" -t chatwoot:commmate-dev -f ./docker/Dockerfile .

# Recreate containers with new image
podman-compose -f docker-compose.commmate.yaml up -d --force-recreate
```

## 🔧 Troubleshooting

### Container won't start

```bash
# Check logs
podman-compose -f docker-compose.commmate.yaml logs rails

# Common issues:
# 1. Database not ready - wait for postgres healthcheck
# 2. Missing SECRET_KEY_BASE - check .env.commmate
# 3. Port 3000 in use - change port in docker-compose.commmate.yaml
```

### Database connection errors

```bash
# Verify postgres is running
podman-compose -f docker-compose.commmate.yaml ps

# Test connection
podman-compose -f docker-compose.commmate.yaml exec postgres psql -U postgres -d chatwoot_commmate
```

### Custom extensions not loading

```bash
# Verify custom directory exists in image
podman-compose -f docker-compose.commmate.yaml exec rails ls -la /app/custom

# Check if Custom module is loaded
podman-compose -f docker-compose.commmate.yaml exec rails bundle exec rails runner "puts ChatwootApp.custom?"
```

## 🎯 Next Steps

1. **Add Kanban Board** - Follow `COMMMATE_EXTENSIONS.md`
2. **Configure Email** - Uncomment SMTP settings in `.env.commmate`
3. **Add Custom Features** - Create files in `custom/app/`
4. **Setup Monitoring** - Add Sentry/NewRelic keys

## 📦 Production Deployment

For production, you'll need to:

1. Build production image (fix asset precompilation issue first)
2. Use production environment variables
3. Setup SSL/TLS
4. Configure external storage (S3, etc.)
5. Setup database backups
6. Use managed Redis/PostgreSQL services

See Chatwoot's official deployment guide for more details.

## 🔐 Security Notes

- ✅ `.env.commmate` is in `.gitignore` (never commit secrets!)
- ⚠️ Change default passwords before production
- 🔒 Use strong SECRET_KEY_BASE (128+ characters)
- 🛡️ Enable SSL in production
- 🔑 Rotate secrets regularly

