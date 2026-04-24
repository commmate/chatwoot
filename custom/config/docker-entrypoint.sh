#!/bin/sh
set -e

echo "🚀 Starting CommMate..."

# Wait for database (same as original Chatwoot)
echo "⏳ Waiting for database..."
until PGPASSWORD=$POSTGRES_PASSWORD psql -h "$POSTGRES_HOST" -U "$POSTGRES_USERNAME" -d "$POSTGRES_DATABASE" -c '\q' 2>/dev/null; do
  echo "Waiting for PostgreSQL..."
  sleep 2
done
echo "✅ Database is ready"

# Use Chatwoot's smart prepare task (handles fresh vs existing intelligently)
echo "📦 Preparing database (using Chatwoot's db:chatwoot_prepare)..."
bundle exec rails db:chatwoot_prepare || {
  echo "⚠️  db:chatwoot_prepare had errors, running migrations separately..."
  bundle exec rails db:migrate
}

# CommMate branding is applied automatically by initializer during Rails startup
# No additional rake task needed - initializer handles it

# Start Rails (same as original Chatwoot)
echo "🎉 Starting Rails server..."
exec bundle exec rails s -b 0.0.0.0

