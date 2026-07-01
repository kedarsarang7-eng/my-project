# DukanX — EC2 Launch & Deployment Guide

> Step-by-step guide to deploy DukanX on AWS EC2 Free Tier (t2.micro)

## Architecture on EC2

```
Internet
   │
   ├─ api.dukanx.com ──→ Nginx :80/443 ──→ sls-backend    :4000 (Admin + Licensing)
   ├─ app.dukanx.com ──→ Nginx :80/443 ──→ app-backend    :5000 (Customer + Staff)
   │
   ├─ PostgreSQL (local on EC2 or RDS)
   ├─ S3 bucket: ultra-billing-storage-2026 (file storage)
   ├─ Cognito User Pool: ap-south-1_7iuDWbz7i (auth)
   └─ DynamoDB: LicenseKeys (license management)
```

---

## Phase 1: Create IAM Role for EC2

> EC2 instances use **IAM Instance Profiles** (not access keys) to securely call AWS services. This is more secure than hardcoding keys.

### Step 1.1 — Create the IAM Policy

1. Go to **AWS Console → IAM → Policies → Create Policy**
2. Click **JSON** tab
3. Paste the contents of `deploy/iam-policy.json` (already in your repo)
4. Click **Next**
5. Name: `DukanX-EC2-Policy`
6. Description: `S3, Cognito, DynamoDB, SNS access for DukanX EC2 backends`
7. Click **Create Policy**

### Step 1.2 — Create the IAM Role

1. Go to **IAM → Roles → Create Role**
2. **Trusted entity type**: AWS Service
3. **Use case**: EC2
4. Click **Next**
5. Search and select: `DukanX-EC2-Policy` (the policy you just created)
6. Click **Next**
7. Role name: `DukanX-EC2-Role`
8. Click **Create Role**

---

## Phase 2: Create Security Group

1. Go to **EC2 → Security Groups → Create Security Group**
2. Name: `DukanX-SG`
3. Description: `DukanX backend servers`
4. VPC: (use default)

**Inbound Rules:**

| Type | Port | Source | Purpose |
|------|------|--------|---------|
| SSH | 22 | My IP | Your SSH access |
| HTTP | 80 | 0.0.0.0/0 | Nginx (redirects to HTTPS) |
| HTTPS | 443 | 0.0.0.0/0 | Nginx + SSL |
| Custom TCP | 5432 | (self / SG ID) | PostgreSQL (if using RDS, open to RDS SG) |

> ⚠️ Do NOT open ports 4000/5000 to the internet. Nginx proxies all traffic.

5. Click **Create Security Group**

---

## Phase 3: Launch EC2 Instance

1. Go to **EC2 → Instances → Launch Instance**

### Settings:

| Setting | Value |
|---------|-------|
| **Name** | `DukanX-Server` |
| **AMI** | Amazon Linux 2023 (Free Tier eligible) |
| **Instance type** | `t2.micro` (Free Tier: 750 hrs/month) |
| **Key pair** | Create new → `dukanx-key` → Download `.pem` file |
| **Network** | Default VPC, any subnet |
| **Security Group** | Select `DukanX-SG` (created above) |
| **Storage** | 20 GB gp3 (Free Tier: up to 30 GB) |

### Advanced Details (expand):

| Setting | Value |
|---------|-------|
| **IAM Instance Profile** | `DukanX-EC2-Role` |
| **Metadata version** | IMDSv2 only (more secure) |

2. Click **Launch Instance**
3. Wait for **Instance State: Running** and **Status Check: 2/2 passed**

---

## Phase 4: Allocate Elastic IP (Static IP)

> Without this, your IP changes every time the instance restarts.

1. Go to **EC2 → Elastic IPs → Allocate Elastic IP address**
2. Click **Allocate**
3. Select the new IP → **Actions → Associate Elastic IP**
4. Choose your `DukanX-Server` instance
5. Click **Associate**

> 📝 Note your Elastic IP: `___.___.___.___ ` — you'll point DNS here.

> ⚠️ Elastic IPs are **free while associated** with a running instance. They cost $0.005/hr if NOT associated.

---

## Phase 5: SSH Into EC2

**Windows (PowerShell):**
```powershell
# No chmod needed — Windows SSH handles .pem permissions automatically
ssh -i "C:\Users\YourName\Downloads\dukanx-key.pem" ec2-user@YOUR_ELASTIC_IP
```

**Linux / macOS (Terminal):**
```bash
chmod 400 dukanx-key.pem
ssh -i dukanx-key.pem ec2-user@YOUR_ELASTIC_IP
```

> If you chose Ubuntu AMI, replace `ec2-user` with `ubuntu`.

---

## Phase 6: Run Setup Script

Once SSH'd into the EC2 instance:

```bash
# Install git first
sudo dnf install -y git     # Amazon Linux 2023
# sudo apt-get install -y git  # Ubuntu

# Clone your repo
git clone https://github.com/kedarsarang7-eng/my-backend.git /home/ec2-user/dukanx
cd /home/ec2-user/dukanx

# Run the setup script (installs Node 22, PM2, Nginx, PostgreSQL, Certbot)
chmod +x deploy/ec2-setup.sh
./deploy/ec2-setup.sh
```

---

## Phase 7: Configure Environment Files

```bash
cd /home/ec2-user/dukanx

# sls-backend .env
cp sls/backend/.env.example sls/backend/.env
nano sls/backend/.env
```

**Fill in these values for `sls/backend/.env`:**

```env
PORT=4000
NODE_ENV=production

# Database (use your RDS or local PostgreSQL)
DATABASE_URL=postgresql://dukanx_admin:YOUR_STRONG_PASSWORD@localhost:5432/dukanx
DB_SSL=false
DB_MAX_CONNECTIONS=8

# Cognito (from your existing setup)
COGNITO_USER_POOL_ID=ap-south-1_7iuDWbz7i
COGNITO_CLIENT_ID=2ts8up52at05ovmag84fs1f0nc
COGNITO_REGION=ap-south-1

# S3
S3_BUCKET_NAME=ultra-billing-storage-2026
S3_REGION=ap-south-1

# CORS (your admin panel domain)
CORS_ORIGIN=https://admin.dukanx.com

# Redis (optional — skip if not using)
# REDIS_URL=redis://localhost:6379

# JWT (generate strong secrets)
JWT_ACCESS_SECRET=GENERATE_A_64_CHAR_RANDOM_STRING
JWT_REFRESH_SECRET=GENERATE_ANOTHER_64_CHAR_RANDOM_STRING
```

```bash
# app-backend .env
cp sls/app-backend/.env.example sls/app-backend/.env
nano sls/app-backend/.env
```

**Fill in `sls/app-backend/.env` with the same DB + Cognito + S3 values.**

> 💡 Generate strong secrets: `openssl rand -hex 32`

---

## Phase 8: Deploy

```bash
cd /home/ec2-user/dukanx
chmod +x deploy/deploy.sh
./deploy/deploy.sh
```

This will:
1. Install dependencies (`npm ci`)
2. Build TypeScript (`npm run build`)
3. Run database migrations
4. Start both backends via PM2
5. Run health checks

---

## Phase 9: Configure Nginx + SSL

```bash
# Copy nginx config
sudo cp deploy/nginx.conf /etc/nginx/sites-available/dukanx

# For Amazon Linux (no sites-available by default):
sudo cp deploy/nginx.conf /etc/nginx/conf.d/dukanx.conf

# Edit to match your domains
sudo nano /etc/nginx/conf.d/dukanx.conf
# Change server_name to your actual domains

# Test and reload
sudo nginx -t
sudo systemctl reload nginx
```

---

## Phase 10: Point DNS

In your domain registrar (GoDaddy, Namecheap, Route53, etc.):

| Record | Name | Value |
|--------|------|-------|
| A | `api.dukanx.com` | YOUR_ELASTIC_IP |
| A | `app.dukanx.com` | YOUR_ELASTIC_IP |

Wait for DNS propagation (5-30 min).

---

## Phase 11: Enable SSL (Free)

```bash
sudo certbot --nginx -d api.dukanx.com -d app.dukanx.com
```

Certbot will:
- Obtain free Let's Encrypt SSL certificates
- Auto-configure Nginx for HTTPS
- Set up auto-renewal (every 90 days)

---

## Verification

```bash
# Check PM2 status
pm2 status

# Check health endpoints
curl https://api.dukanx.com/api/health
curl https://app.dukanx.com/api/health

# Check logs
pm2 logs

# Monitor memory/CPU
pm2 monit
```

---

## Ongoing Operations

### Update/Redeploy
```bash
cd /home/ec2-user/dukanx
./deploy/deploy.sh --update
```

### View Logs
```bash
pm2 logs sls-backend --lines 50
pm2 logs app-backend --lines 50
```

### Restart Services
```bash
pm2 restart all
```

### Run Migrations (after schema changes)
```bash
cd /home/ec2-user/dukanx/sls/backend
npm run migrate
```

---

## Free Tier Budget Checklist

| Service | Free Tier Limit | DukanX Usage |
|---------|----------------|--------------|
| EC2 t2.micro | 750 hrs/month | 1 instance = 730 hrs ✅ |
| EBS gp3 | 30 GB | 20 GB ✅ |
| S3 | 5 GB + 20K GET + 2K PUT | Well within ✅ |
| RDS db.t3.micro | 750 hrs + 20 GB | Optional (using local PG) ✅ |
| Cognito | 50,000 MAU | Well within ✅ |
| DynamoDB | 25 GB + 25 WCU/RCU | Well within ✅ |
| Elastic IP | Free while associated | 1 IP ✅ |
| Data Transfer | 100 GB/month out | Well within ✅ |

> ⚠️ Free Tier expires **12 months** after AWS account creation. Set up a **Billing Alarm** (CloudWatch → Alarms → Billing) for $5 threshold.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `pm2 status` shows errored | `pm2 logs <name> --lines 50` to see error |
| Port already in use | `sudo lsof -i :4000` then `kill -9 <PID>` |
| Nginx 502 Bad Gateway | Backend not running — check `pm2 status` |
| Cannot connect to DB | Check `DATABASE_URL` in `.env`, verify PostgreSQL is running |
| Cognito token rejected | Verify `COGNITO_USER_POOL_ID` and client IDs match |
| S3 access denied | Verify IAM Instance Profile is attached to EC2 |
