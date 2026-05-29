#!/bin/bash
# ============================================================================
# DukanX — Automated Deployment Script
# ============================================================================
# Run this AFTER ec2-setup.sh has completed.
# This script: clones repo → installs deps → builds → migrates → starts PM2
#
# Usage:
#   chmod +x deploy/deploy.sh
#   ./deploy/deploy.sh
#
# For subsequent deploys (updates):
#   ./deploy/deploy.sh --update
# ============================================================================

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
APP_DIR="/home/ec2-user/dukanx"
REPO_URL="https://github.com/kedarsarang7-eng/my-backend.git"
BRANCH="main"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ── Parse Arguments ──────────────────────────────────────────────────────────
UPDATE_MODE=false
if [[ "${1:-}" == "--update" ]]; then
    UPDATE_MODE=true
    log "Running in UPDATE mode (pull + rebuild + restart)"
fi

echo ""
echo "=========================================="
echo " DukanX Deployment"
echo "=========================================="
echo ""

# ── Step 1: Clone or Pull ───────────────────────────────────────────────────
if [ "$UPDATE_MODE" = true ]; then
    log "Step 1: Pulling latest code..."
    cd "$APP_DIR"
    git pull origin "$BRANCH"
else
    if [ -d "$APP_DIR/.git" ]; then
        warn "Directory $APP_DIR already exists. Use --update flag for updates."
        warn "Pulling latest instead..."
        cd "$APP_DIR"
        git pull origin "$BRANCH"
    else
        log "Step 1: Cloning repository..."
        git clone --branch "$BRANCH" "$REPO_URL" "$APP_DIR"
        cd "$APP_DIR"
    fi
fi

# ── Step 2: Check .env Files ────────────────────────────────────────────────
log "Step 2: Checking environment files..."

check_env() {
    local dir=$1
    local name=$2
    if [ ! -f "$dir/.env" ]; then
        if [ -f "$dir/.env.example" ]; then
            warn "$name: .env missing! Creating from .env.example..."
            cp "$dir/.env.example" "$dir/.env"
            err "$name: Please edit $dir/.env with real values, then re-run this script."
        else
            err "$name: No .env or .env.example found!"
        fi
    else
        log "$name: .env exists"
    fi
}

check_env "$APP_DIR/sls/backend" "sls-backend"
check_env "$APP_DIR/sls/app-backend" "app-backend"

# ── Step 3: Install Dependencies ────────────────────────────────────────────
log "Step 3: Installing dependencies..."

log "  → sls/backend..."
cd "$APP_DIR/sls/backend"
npm ci --production=false 2>&1 | tail -1

log "  → sls/app-backend..."
cd "$APP_DIR/sls/app-backend"
npm ci --production=false 2>&1 | tail -1

# ── Step 4: Build TypeScript ────────────────────────────────────────────────
log "Step 4: Building TypeScript..."

log "  → sls/backend..."
cd "$APP_DIR/sls/backend"
npm run build
log "  → sls/backend build complete"

log "  → sls/app-backend..."
cd "$APP_DIR/sls/app-backend"
npm run build
log "  → sls/app-backend build complete"

# ── Step 5: Run Database Migrations ─────────────────────────────────────────
if [ "$UPDATE_MODE" = false ]; then
    log "Step 5: Running database migrations..."
    cd "$APP_DIR/sls/backend"
    npm run migrate
    log "  → Migrations complete"
else
    warn "Step 5: Skipping migrations in update mode (run manually if needed)"
    warn "  To run: cd $APP_DIR/sls/backend && npm run migrate"
fi

# ── Step 6: Start/Restart PM2 ───────────────────────────────────────────────
log "Step 6: Starting services with PM2..."
cd "$APP_DIR"

if [ "$UPDATE_MODE" = true ]; then
    pm2 restart ecosystem.config.js
    log "  → PM2 processes restarted"
else
    # Stop any existing processes
    pm2 delete all 2>/dev/null || true

    # Start fresh
    pm2 start ecosystem.config.js
    log "  → PM2 processes started"

    # Save PM2 process list (survives reboot)
    pm2 save
    log "  → PM2 process list saved"

    # Setup PM2 startup script (auto-start on reboot)
    # This generates a command you may need to run with sudo
    STARTUP_CMD=$(pm2 startup 2>&1 | grep "sudo" | head -1)
    if [ -n "$STARTUP_CMD" ]; then
        warn "Run this command to enable auto-start on reboot:"
        echo "  $STARTUP_CMD"
    fi
fi

# ── Step 7: Health Check ────────────────────────────────────────────────────
log "Step 7: Running health checks..."
sleep 3  # Give servers time to start

check_health() {
    local port=$1
    local name=$2
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port/api/health" 2>/dev/null || echo "000")
    if [ "$response" = "200" ]; then
        log "  $name (port $port): ✅ HEALTHY"
    else
        err "  $name (port $port): ❌ UNHEALTHY (HTTP $response)"
    fi
}

check_health 4000 "sls-backend"
check_health 5000 "app-backend"

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "=========================================="
echo -e " ${GREEN}Deployment Complete!${NC}"
echo "=========================================="
echo ""
echo " Services:"
echo "   sls-backend:  http://localhost:4000/api/health"
echo "   app-backend:  http://localhost:5000/api/health"
echo ""
echo " Useful Commands:"
echo "   pm2 status          — View process status"
echo "   pm2 logs            — View live logs"
echo "   pm2 monit           — Live monitoring dashboard"
echo "   pm2 restart all     — Restart all services"
echo ""
echo " Next Steps:"
echo "   1. Configure Nginx:  sudo cp deploy/nginx.conf /etc/nginx/sites-available/dukanx"
echo "   2. Enable site:      sudo ln -s /etc/nginx/sites-available/dukanx /etc/nginx/sites-enabled/"
echo "   3. Test Nginx:       sudo nginx -t && sudo systemctl reload nginx"
echo "   4. Setup SSL:        sudo certbot --nginx -d api.dukanx.com -d app.dukanx.com"
echo ""
