# Tico Mail Works - CRM Deployment

Production deployment of CommMate CRM branded for **Tico Mail Works** (www.ticomailworks.ie).

Uses `commmate/commmate:v4.11.1.3` with runtime brand color customization -- no image rebuild needed.

## Branding

| Setting | Value |
|---------|-------|
| Brand Name | Tico Mail Works |
| Primary Color | `#4681CF` (blue) |
| Logo | White envelope icon + text (SVG) |
| Locale | English (`en`) |
| Timezone | Europe/Dublin |

## Quick Start

```bash
# 1. Copy and configure environment
cp .env.example .env
# Edit .env with actual passwords and domains

# 2. Generate SFTP keypair
mkdir -p sftp_keys
ssh-keygen -t ed25519 -f sftp_keys/tmw_sftp_key -N ""
cp sftp_keys/tmw_sftp_key.pub sftp_keys/authorized_keys

# 3. Start all services
docker compose up -d

# 4. Verify
docker compose ps
curl -sI https://crm.ticomailworks.ie
```

## Services

| Service | Container | Port | URL |
|---------|-----------|------|-----|
| CRM | tmw-rails | 3000 | https://crm.ticomailworks.ie |
| Sidekiq | tmw-sidekiq | - | - |
| PostgreSQL | tmw-postgres | 5432 | internal |
| Redis | tmw-redis | 6379 | internal |
| Evolution API | tmw-evolution | 8080 | https://evolution.ticomailworks.ie |
| SFTP | tmw-sftp | 2222 | sftp://sftp_user@host:2222 |
| Traefik | tmw-traefik | 80/443 | - |

## Post-Deploy Configuration

After the first boot, access Super Admin and configure:

1. **SFTP settings** (via `rails runner` or Super Admin UI):
   - `SFTP_CAMPAIGNS_HOST` = `tmw-sftp`
   - `SFTP_CAMPAIGNS_PORT` = `22`
   - `SFTP_CAMPAIGNS_USERNAME` = `sftp_user`
   - `SFTP_CAMPAIGNS_REMOTE_PATH` = `/campaigns`
   - `SFTP_CAMPAIGNS_PRIVATE_KEY` = contents of `sftp_keys/tmw_sftp_key`

2. **Create a Resend inbox** with the sending domain matching `ticomailworks.ie`

3. **Enable SFTP on the inbox**: set `sftp_campaigns_enabled: true` in the inbox provider config

## File Structure

```
ticomailworks/
├── docker-compose.yaml     # All services
├── .env.example            # Template for environment variables
├── .env                    # Actual environment (git-ignored)
├── brand-assets/
│   ├── logo.svg            # TMW logo (white on transparent)
│   └── favicon.png         # TMW favicon
├── sftp_keys/
│   ├── tmw_sftp_key        # Private key (git-ignored)
│   ├── tmw_sftp_key.pub    # Public key
│   └── authorized_keys     # Copy of public key for SFTP container
└── README.md
```
