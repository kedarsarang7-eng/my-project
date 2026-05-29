# 🚀 DukanX Local AWS Cloud — Setup & Installation Guide

## Prerequisites

### Windows (Your Setup)

```powershell
# 1. Docker Desktop (required)
winget install Docker.DockerDesktop
# After install → Settings → Resources → Memory: 8GB, CPUs: 4

# 2. WSL2 (recommended for shell scripts)
wsl --install

# 3. Node.js 22+ (you already have this)
winget install OpenJS.NodeJS.LTS

# 4. AWS CLI v2
winget install Amazon.AWSCLI

# 5. Terraform
winget install Hashicorp.Terraform

# 6. Make (for Makefile)
winget install GnuWin32.Make
# OR use chocolatey: choco install make

# 7. (Optional) LocalStack CLI
pip install localstack

# 8. (Optional) awslocal wrapper
pip install awscli-local
```

### macOS

```bash
# 1. Docker Desktop
brew install --cask docker

# 2. Node.js 22+
brew install node@22

# 3. AWS CLI v2
brew install awscli

# 4. Terraform
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# 5. (Optional) LocalStack CLI
brew install localstack/tap/localstack-cli

# 6. (Optional) awslocal
pip3 install awscli-local
```

### Linux (Ubuntu/Debian)

```bash
# 1. Docker Engine + Compose v2
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-v2
sudo usermod -aG docker $USER
newgrp docker

# 2. Node.js 22+
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs

# 3. AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# 4. Terraform
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y terraform

# 5. LocalStack + awslocal
pip3 install localstack awscli-local
```

---

## Quick Start (One Command)

```powershell
# From project root:

# Step 1: Install local-cloud dependencies
cd local-cloud && npm install && cd ..

# Step 2: Boot the entire local AWS environment
npm run cloud:up

# Step 3: Wait for health check, then seed
npm run cloud:seed

# Step 4: Verify everything works
npm run cloud:smoke

# Step 5: Get a local JWT token for API testing
npm run cloud:auth
```

---

## Detailed Boot Sequence

```powershell
# 1. Start Docker services
docker compose -f local-cloud/docker-compose.yml up -d

# 2. Wait for LocalStack (takes 20-40s on first run)
curl http://localhost:4566/_localstack/health

# 3. Init scripts auto-run via init hooks:
#    - Creates 10 DynamoDB tables with GSIs
#    - Creates 3 S3 buckets
#    - Creates 4 SQS queues (with DLQ)
#    - Creates 4 SNS topics
#    - Creates EventBridge bus + rules
#    - Creates Secrets Manager secrets
#    - Creates SSM parameters
#    - Creates Cognito user pool + 3 clients
#    - Creates 2 test users

# 4. Seed test data
bash local-cloud/init/02-seed-data.sh

# 5. (Optional) Terraform alternative
cd local-cloud/terraform
terraform init
terraform apply -auto-approve
```

---

## Daily Development Workflow

```powershell
# Morning: Boot environment
npm run cloud:up

# Check health
npm run cloud:smoke

# Get auth token
npm run cloud:auth
# Copy the token for API testing

# Invoke a Lambda directly
node local-cloud/scripts/invoke-lambda.mjs billingHandler '{
  "httpMethod": "GET",
  "path": "/billing/plans",
  "headers": {"authorization": "Bearer YOUR_TOKEN"},
  "requestContext": {"http": {"method": "GET", "path": "/billing/plans"}}
}'

# Debug in VSCode: Use "Debug Lambda — Billing Handler" launch config

# View DynamoDB data
aws --endpoint-url=http://localhost:4566 --region ap-south-1 dynamodb scan --table-name dukan-saas-dev-tenants

# View emails (Mailhog UI)
# Open http://localhost:8025

# View traces (if Jaeger running)
# Open http://localhost:16686

# End of day: Stop (preserves data)
npm run cloud:down
```

---

## Command Reference

| Command | Description |
|---------|-------------|
| `npm run cloud:up` | Boot local AWS cloud |
| `npm run cloud:down` | Stop all services |
| `npm run cloud:logs` | Follow LocalStack logs |
| `npm run cloud:status` | Show service health |
| `npm run cloud:seed` | Seed DynamoDB with test data |
| `npm run cloud:smoke` | Run smoke tests |
| `npm run cloud:auth` | Generate local JWT token |
| `npm run cloud:invoke` | Invoke Lambda handler |
| `npm run cloud:test` | Run integration tests |
| `make up` | Boot (via Makefile) |
| `make tf-apply` | Apply Terraform to LocalStack |
| `make db-scan TABLE=name` | Scan a DynamoDB table |
| `make sqs-send QUEUE=name MSG='{}'` | Send SQS message |
| `make event-put` | Put EventBridge event |
| `make test-load` | Run Artillery load test |

---

## Testing Strategy

### Pyramid

```
         /\
        /  \
       / E2E \        ← Playwright (browser tests)
      /________\
     /  Integra  \     ← local-cloud/tests/integration.mjs
    /______________\
   /   Unit Tests    \  ← lambda/jest (handler logic)
  /____________________\
```

### Running Tests

```powershell
# Unit tests (no Docker needed)
cd lambda && npm test

# Integration tests (requires: npm run cloud:up)
npm run cloud:test

# Smoke tests (quick service check)
npm run cloud:smoke

# E2E tests (Flutter PWA + API)
npm test

# Load tests (requires: npm run cloud:up + artillery)
npx artillery run local-cloud/tests/load-test.yml
```

---

## Folder Structure

```
local-cloud/
├── docker-compose.yml           # Core Docker services
├── docker-compose.override.yml  # Low-RAM overrides
├── .env.local.example           # Environment template
├── .gitignore                   # Ignore volumes, state, keys
├── package.json                 # Local cloud dependencies
│
├── init/                        # LocalStack init hooks (auto-run)
│   ├── 01-create-resources.sh   # Tables, queues, topics, secrets
│   └── 02-seed-data.sh          # Test data
│
├── terraform/                   # IaC (primary)
│   ├── main.tf                  # Provider config → LocalStack
│   ├── variables.tf             # Stack name, region, endpoint
│   ├── dynamodb.tf              # 8 DynamoDB tables
│   ├── services.tf              # S3, SQS, SNS, EventBridge, Secrets
│   ├── cognito.tf               # User pool + clients
│   ├── stepfunctions.tf         # Trial provisioning workflow
│   └── outputs.tf               # Resource identifiers
│
├── cdk-alternative/             # CDK option (if preferred)
│   └── lib/local-stack.mjs      # CDK constructs
│
├── scripts/                     # Dev tooling
│   ├── local-auth.mjs           # JWT token generator
│   ├── invoke-lambda.mjs        # Direct Lambda invocation
│   └── smoke-test.mjs           # Service health check
│
├── examples/                    # Working demos
│   ├── eventbridge-demo.mjs     # EventBridge + SQS
│   ├── sqs-sns-demo.mjs         # Message queue patterns
│   └── stepfunctions-demo.mjs   # Workflow execution
│
├── tests/                       # Test suites
│   ├── integration.mjs          # Full integration tests
│   └── load-test.yml            # Artillery load test
│
└── hooks/                       # Git hooks
    └── pre-commit               # Secret scanning, linting
```

---

## Environment Isolation (dev / staging / prod)

```powershell
# Dev (default)
STACK_NAME=dukan-saas-dev docker compose -f local-cloud/docker-compose.yml up -d

# Staging
STACK_NAME=dukan-saas-staging docker compose -f local-cloud/docker-compose.yml up -d

# The init scripts use $STACK as prefix, so all resources are namespaced:
# dukan-saas-dev-tenants vs dukan-saas-staging-tenants
```

To run different environments simultaneously, change the port mapping in an override file.
