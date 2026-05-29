#!/bin/bash
# ============================================================================
# DukanX — EC2 Instance Setup Script (Amazon Linux 2023 / Ubuntu 22.04)
# ============================================================================
# Run this script on a fresh EC2 t2.micro Free Tier instance.
#
# Usage:
#   chmod +x deploy/ec2-setup.sh
#   ./deploy/ec2-setup.sh
#
# Prerequisites:
#   - EC2 t2.micro with Amazon Linux 2023 or Ubuntu 22.04
#   - Security Group: ports 22 (SSH), 80 (HTTP), 443 (HTTPS)
#   - IAM Instance Profile with S3, Cognito, DynamoDB permissions
#   - PostgreSQL either on RDS (recommended) or local (cost-saving)
# ============================================================================

set -euo pipefail

echo "=========================================="
echo " DukanX EC2 Setup — Starting..."
echo "=========================================="

# ── 1. System Updates ────────────────────────────────────────────────────────
echo "[1/7] Updating system packages..."
if command -v dnf &> /dev/null; then
    sudo dnf update -y
    PKG_MANAGER="dnf"
elif command -v apt-get &> /dev/null; then
    sudo apt-get update -y && sudo apt-get upgrade -y
    PKG_MANAGER="apt-get"
else
    echo "Unsupported OS. Use Amazon Linux 2023 or Ubuntu 22.04."
    exit 1
fi

# ── 2. Install Node.js 22 LTS ───────────────────────────────────────────────
echo "[2/7] Installing Node.js 22 LTS..."
if ! command -v node &> /dev/null || [[ $(node -v | cut -d. -f1 | tr -d 'v') -lt 22 ]]; then
    curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash - 2>/dev/null || \
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo $PKG_MANAGER install -y nodejs
fi
echo "  Node: $(node -v)"
echo "  npm:  $(npm -v)"

# ── 3. Install PM2 (Process Manager) ────────────────────────────────────────
echo "[3/7] Installing PM2..."
sudo npm install -g pm2
pm2 --version

# ── 4. Install Nginx (Reverse Proxy) ────────────────────────────────────────
echo "[4/7] Installing Nginx..."
sudo $PKG_MANAGER install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx

# ── 5. Install PostgreSQL 16 (Local — Cost Saving) ──────────────────────────
echo "[5/7] Installing PostgreSQL 16 (local)..."
if [ "$PKG_MANAGER" = "dnf" ]; then
    sudo dnf install -y postgresql16-server postgresql16
    sudo postgresql-setup --initdb 2>/dev/null || true
else
    sudo apt-get install -y postgresql postgresql-contrib
fi
sudo systemctl enable postgresql
sudo systemctl start postgresql

echo "  Creating database and user..."
sudo -u postgres psql -c "CREATE USER dukanx_admin WITH PASSWORD 'CHANGE_ME_STRONG_PASSWORD';" 2>/dev/null || true
sudo -u postgres psql -c "CREATE DATABASE dukanx OWNER dukanx_admin;" 2>/dev/null || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE dukanx TO dukanx_admin;" 2>/dev/null || true

# ── 6. Create App Directory ─────────────────────────────────────────────────
echo "[6/7] Setting up application directory..."
APP_DIR="/home/ec2-user/dukanx"
mkdir -p "$APP_DIR"
mkdir -p /var/log/pm2

# ── 7. SSL with Certbot (Let's Encrypt) ─────────────────────────────────────
echo "[7/7] Installing Certbot for SSL..."
if [ "$PKG_MANAGER" = "dnf" ]; then
    sudo dnf install -y certbot python3-certbot-nginx
else
    sudo apt-get install -y certbot python3-certbot-nginx
fi

echo ""
echo "=========================================="
echo " Setup Complete!"
echo "=========================================="
echo ""
echo " Next Steps:"
echo "  1. Clone your repo to $APP_DIR"
echo "  2. Copy .env.example → .env in sls/backend/ and sls/app-backend/"
echo "  3. Fill in real values (DB creds, Cognito IDs, S3 bucket)"
echo "  4. Run in each backend:"
echo "       npm install && npm run build"
echo "  5. Run database migrations:"
echo "       cd sls/backend && npm run migrate"
echo "  6. Copy nginx config:"
echo "       sudo cp deploy/nginx.conf /etc/nginx/sites-available/dukanx"
echo "       sudo ln -s /etc/nginx/sites-available/dukanx /etc/nginx/sites-enabled/"
echo "       sudo nginx -t && sudo systemctl reload nginx"
echo "  7. Start with PM2:"
echo "       pm2 start ecosystem.config.js"
echo "       pm2 save && pm2 startup"
echo "  8. Setup SSL:"
echo "       sudo certbot --nginx -d api.dukanx.com -d app.dukanx.com"
echo ""
echo " Health Checks:"
echo "   curl http://localhost:4000/api/health"
echo "   curl http://localhost:5000/api/health"
echo ""
echo " Monitor:"
echo "   pm2 monit"
echo "   pm2 logs"
echo ""
