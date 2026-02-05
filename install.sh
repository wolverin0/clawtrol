#!/bin/bash
set -e

echo "🦞 Installing ClawDeck..."
echo ""

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check for Docker Compose
if ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose is not available. Please install Docker Compose."
    exit 1
fi

# Generate secret key if not set
if [ -z "$SECRET_KEY_BASE" ]; then
    echo "🔑 Generating SECRET_KEY_BASE..."
    export SECRET_KEY_BASE=$(openssl rand -hex 64)
    echo "   Generated: ${SECRET_KEY_BASE:0:16}..."
    
    # Save to .env file for persistence
    echo "SECRET_KEY_BASE=$SECRET_KEY_BASE" > .env.production
    echo "   Saved to .env.production"
fi

# Build and start containers
echo ""
echo "🐳 Building Docker images..."
docker compose build

echo ""
echo "🚀 Starting services..."
docker compose up -d

# Wait for database to be healthy
echo ""
echo "⏳ Waiting for database to be ready..."
timeout=60
counter=0
until docker compose exec -T db pg_isready -U postgres -d clawdeck_production > /dev/null 2>&1; do
    counter=$((counter + 1))
    if [ $counter -ge $timeout ]; then
        echo "❌ Database failed to start within ${timeout} seconds"
        docker compose logs db
        exit 1
    fi
    sleep 1
    printf "."
done
echo " Ready!"

# Run database migrations
echo ""
echo "📦 Running database migrations..."
docker compose exec -T clawdeck bundle exec rails db:prepare

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 ClawDeck is running!"
echo ""
echo "   URL: http://localhost:4001"
echo "   Status: docker compose ps"
echo "   Logs: docker compose logs -f clawdeck"
echo "   Stop: docker compose down"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
