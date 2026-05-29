# =============================================================================
# DukanX Local AWS Cloud — Makefile
# =============================================================================
# Single-command operations for the entire local cloud environment.
#
# Quick start:
#   make up        — Boot entire local AWS cloud
#   make down      — Shut down everything
#   make restart   — Restart all services
#   make status    — Show health of all services
#   make logs      — Follow LocalStack logs
#   make test      — Run integration tests
# =============================================================================

.PHONY: help up down restart status logs seed test invoke deploy clean

COMPOSE := docker compose -f local-cloud/docker-compose.yml
COMPOSE_ALL := $(COMPOSE) --profile observability --profile analytics
AWS := aws --endpoint-url=http://localhost:4566 --region ap-south-1
TF := cd local-cloud/terraform && terraform
STACK := dukan-saas-dev

# Colors
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

# ─── Environment Lifecycle ──────────────────────────────────────────────

up: ## Boot full local AWS cloud
	@echo "$(GREEN)━━━ Starting DukanX Local Cloud ━━━$(NC)"
	$(COMPOSE) up -d
	@echo "$(YELLOW)Waiting for LocalStack health check...$(NC)"
	@timeout 120 bash -c 'until curl -s http://localhost:4566/_localstack/health | grep -q running; do sleep 2; done'
	@echo "$(GREEN)✓ LocalStack ready$(NC)"
	@echo ""
	@echo "$(GREEN)━━━ Services Running ━━━$(NC)"
	@echo "  LocalStack:  http://localhost:4566"
	@echo "  Redis:       redis://localhost:6379"
	@echo "  Mailhog UI:  http://localhost:8025"
	@echo ""

up-full: ## Boot everything including Jaeger and PostgreSQL
	$(COMPOSE_ALL) up -d
	@timeout 120 bash -c 'until curl -s http://localhost:4566/_localstack/health | grep -q running; do sleep 2; done'
	@echo "$(GREEN)✓ Full stack ready$(NC)"
	@echo "  Jaeger UI:   http://localhost:16686"
	@echo "  PostgreSQL:  localhost:5432"

down: ## Shut down all services
	$(COMPOSE_ALL) down

down-clean: ## Shut down and delete all data volumes
	$(COMPOSE_ALL) down -v
	rm -rf local-cloud/volume

restart: ## Restart all services
	$(COMPOSE) restart

status: ## Show health of all services
	@echo "$(GREEN)━━━ Service Health ━━━$(NC)"
	@curl -s http://localhost:4566/_localstack/health | python3 -m json.tool 2>/dev/null || echo "$(RED)LocalStack: DOWN$(NC)"
	@docker compose -f local-cloud/docker-compose.yml ps
	@echo ""
	@echo "$(GREEN)━━━ DynamoDB Tables ━━━$(NC)"
	@$(AWS) dynamodb list-tables --query 'TableNames' --output table 2>/dev/null || echo "$(RED)DynamoDB: Not reachable$(NC)"

logs: ## Follow LocalStack logs
	$(COMPOSE) logs -f localstack

logs-all: ## Follow all service logs
	$(COMPOSE) logs -f

# ─── Infrastructure as Code ─────────────────────────────────────────────

tf-init: ## Initialize Terraform
	$(TF) init

tf-plan: ## Plan Terraform changes
	$(TF) plan

tf-apply: ## Apply Terraform resources to LocalStack
	$(TF) apply -auto-approve

tf-destroy: ## Destroy all Terraform-managed resources
	$(TF) destroy -auto-approve

# ─── Database Operations ────────────────────────────────────────────────

seed: ## Seed DynamoDB with test data
	@echo "$(YELLOW)Seeding databases...$(NC)"
	@bash local-cloud/init/02-seed-data.sh
	@echo "$(GREEN)✓ Seeding complete$(NC)"

db-list: ## List all DynamoDB tables
	@$(AWS) dynamodb list-tables --output table

db-scan: ## Scan a table (usage: make db-scan TABLE=dukan-saas-dev-tenants)
	@$(AWS) dynamodb scan --table-name $(TABLE) --output json | python3 -m json.tool

db-count: ## Count items in all tables
	@for table in $$($(AWS) dynamodb list-tables --query 'TableNames[]' --output text); do \
		count=$$($(AWS) dynamodb scan --table-name $$table --select COUNT --query 'Count' --output text); \
		echo "  $$table: $$count items"; \
	done

# ─── Lambda Operations ──────────────────────────────────────────────────

invoke-tenant-list: ## Invoke TenantHandler — list tenants
	@node local-cloud/scripts/invoke-lambda.mjs tenantHandler '{"httpMethod":"GET","path":"/tenants","headers":{"authorization":"Bearer $(TOKEN)"},"requestContext":{"http":{"method":"GET","path":"/tenants"}}}'

invoke-billing-plans: ## Invoke BillingHandler — list plans
	@node local-cloud/scripts/invoke-lambda.mjs billingHandler '{"httpMethod":"GET","path":"/billing/plans","headers":{"authorization":"Bearer $(TOKEN)"},"requestContext":{"http":{"method":"GET","path":"/billing/plans"}}}'

# ─── Auth Operations ────────────────────────────────────────────────────

auth-token: ## Get a local JWT token for testing
	@node local-cloud/scripts/local-auth.mjs token

auth-signup: ## Create test user (usage: make auth-signup EMAIL=test@test.com)
	@node local-cloud/scripts/local-auth.mjs signup $(EMAIL) $(PASSWORD)

auth-login: ## Login test user (usage: make auth-login EMAIL=test@test.com PASSWORD=Test@1234)
	@node local-cloud/scripts/local-auth.mjs login $(EMAIL) $(PASSWORD)

# ─── Testing ─────────────────────────────────────────────────────────────

test: ## Run all integration tests
	@echo "$(GREEN)━━━ Running Integration Tests ━━━$(NC)"
	cd lambda && npm test

test-smoke: ## Run smoke tests against local API
	@node local-cloud/scripts/smoke-test.mjs

test-e2e: ## Run Playwright e2e tests
	npx playwright test

test-load: ## Run load test (requires artillery)
	npx artillery run local-cloud/tests/load-test.yml

# ─── Queue / Event Operations ───────────────────────────────────────────

sqs-send: ## Send test message to SQS (usage: make sqs-send QUEUE=email-notifications MSG='{"test":true}')
	@$(AWS) sqs send-message \
		--queue-url http://localhost:4566/000000000000/$(STACK)-$(QUEUE) \
		--message-body '$(MSG)'

sqs-receive: ## Receive messages from SQS (usage: make sqs-receive QUEUE=email-notifications)
	@$(AWS) sqs receive-message \
		--queue-url http://localhost:4566/000000000000/$(STACK)-$(QUEUE) \
		--max-number-of-messages 10 \
		--output json | python3 -m json.tool

event-put: ## Put event to EventBridge
	@$(AWS) events put-events --entries '[{"Source":"dukan.billing","DetailType":"SubscriptionCreated","Detail":"{\"tenantId\":\"tenant-001\",\"plan\":\"premium\"}","EventBusName":"$(STACK)-main-bus"}]'

sns-publish: ## Publish to SNS topic (usage: make sns-publish TOPIC=tenant-events MSG='{"test":true}')
	@$(AWS) sns publish \
		--topic-arn arn:aws:sns:ap-south-1:000000000000:$(STACK)-$(TOPIC) \
		--message '$(MSG)'

# ─── Secrets & Config ───────────────────────────────────────────────────

secrets-list: ## List all secrets
	@$(AWS) secretsmanager list-secrets --output table

secrets-get: ## Get a secret (usage: make secrets-get NAME=dukan-saas-dev/jwt-signing-key)
	@$(AWS) secretsmanager get-secret-value --secret-id $(NAME) --query 'SecretString' --output text | python3 -m json.tool

ssm-list: ## List all SSM parameters
	@$(AWS) ssm get-parameters-by-path --path "/$(STACK)/" --recursive --output table

# ─── Cleanup ─────────────────────────────────────────────────────────────

clean: ## Remove all local data and volumes
	@echo "$(RED)WARNING: This will delete all local data!$(NC)"
	@read -p "Continue? (y/N) " confirm && [ "$$confirm" = "y" ] || exit 1
	$(COMPOSE_ALL) down -v
	rm -rf local-cloud/volume
	rm -rf local-cloud/terraform/.terraform
	rm -f local-cloud/terraform/terraform.tfstate*
	@echo "$(GREEN)✓ Clean complete$(NC)"
