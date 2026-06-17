# =============================================================================
# DynamoDB Tables — Mirrors template.yaml exactly
# =============================================================================

locals {
  table_prefix = var.stack_name
}

# ─── Auth Sessions ──────────────────────────────────────────────────────

resource "aws_dynamodb_table" "auth_sessions" {
  name         = "${local.table_prefix}-auth-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "sessionId"

  attribute {
    name = "sessionId"
    type = "S"
  }

  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  # COST-OPT: Stream removed — no consumer Lambda exists for this table
  # stream_enabled   = true
  # stream_view_type = "NEW_AND_OLD_IMAGES"

  # COST-OPT: PITR disabled — ephemeral session data, TTL-expired
  # point_in_time_recovery {
  #   enabled = true
  # }

  tags = {
    Environment = var.environment
    Service     = "auth"
  }
}

# ─── Tenants ────────────────────────────────────────────────────────────

resource "aws_dynamodb_table" "tenants" {
  name         = "${local.table_prefix}-tenants"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "tenantId"

  attribute {
    name = "tenantId"
    type = "S"
  }
  attribute {
    name = "plan"
    type = "S"
  }
  attribute {
    name = "slug"
    type = "S"
  }
  attribute {
    name = "createdAt"
    type = "S"
  }
  attribute {
    name = "ownerUserId"
    type = "S"
  }

  global_secondary_index {
    name            = "GSI_Plan"
    hash_key        = "plan"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "GSI_Slug"
    hash_key        = "slug"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "GSI_Owner"
    hash_key        = "ownerUserId"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "deleteAt"
    enabled        = true
  }

  # COST-OPT: Stream removed — no consumer Lambda exists for this table
  # stream_enabled   = true
  # stream_view_type = "NEW_AND_OLD_IMAGES"

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Environment = var.environment
    Service     = "tenants"
  }
}

# ─── Users ──────────────────────────────────────────────────────────────

resource "aws_dynamodb_table" "users" {
  name         = "${local.table_prefix}-users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "tenantId#userId"

  attribute {
    name = "tenantId#userId"
    type = "S"
  }
  attribute {
    name = "email"
    type = "S"
  }
  attribute {
    name = "tenantId"
    type = "S"
  }
  attribute {
    name = "role#userId"
    type = "S"
  }

  global_secondary_index {
    name            = "GSI_Email"
    hash_key        = "email"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "GSI_TenantRole"
    hash_key        = "tenantId"
    range_key       = "role#userId"
    projection_type = "ALL"
  }

  # COST-OPT: Stream removed — no consumer Lambda exists for this table
  # stream_enabled   = true
  # stream_view_type = "NEW_AND_OLD_IMAGES"

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Environment = var.environment
    Service     = "users"
  }
}

# ─── Billing ────────────────────────────────────────────────────────────

resource "aws_dynamodb_table" "billing" {
  name         = "${local.table_prefix}-billing"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "tenantId"
  range_key    = "SK"

  attribute {
    name = "tenantId"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }
  attribute {
    name = "status"
    type = "S"
  }
  attribute {
    name = "dueAt"
    type = "S"
  }

  global_secondary_index {
    name            = "GSI_BillingStatus"
    hash_key        = "status"
    range_key       = "dueAt"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  # COST-OPT: Stream removed — no consumer Lambda exists for this table
  # stream_enabled   = true
  # stream_view_type = "NEW_AND_OLD_IMAGES"

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Environment = var.environment
    Service     = "billing"
  }
}

# ─── Audit Logs ─────────────────────────────────────────────────────────

resource "aws_dynamodb_table" "audit_logs" {
  name         = "${local.table_prefix}-audit-logs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "tenantId"
  range_key    = "SK"

  attribute {
    name = "tenantId"
    type = "S"
  }
  attribute {
    name = "tenantId#userId"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }

  global_secondary_index {
    name            = "GSI_UserAudit"
    hash_key        = "tenantId#userId"
    range_key       = "SK"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  # COST-OPT: Stream removed — no consumer Lambda exists for this table
  # stream_enabled   = true
  # stream_view_type = "NEW_AND_OLD_IMAGES"

  # COST-OPT: PITR disabled — TTL-expired audit logs, regenerable
  # point_in_time_recovery {
  #   enabled = true
  # }

  tags = {
    Environment = var.environment
    Service     = "audit"
  }
}

# ─── Customer Tables ───────────────────────────────────────────────────

resource "aws_dynamodb_table" "customer_invoices" {
  name         = "${local.table_prefix}-customer-invoices"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }
  attribute {
    name = "customerId"
    type = "S"
  }
  attribute {
    name = "createdAt"
    type = "S"
  }

  global_secondary_index {
    name            = "GSI_Customer"
    hash_key        = "customerId"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Environment = var.environment
    Service     = "customer"
  }
}

resource "aws_dynamodb_table" "customer_ledger" {
  name         = "${local.table_prefix}-customer-ledger"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }
  attribute {
    name = "customerId"
    type = "S"
  }
  attribute {
    name = "createdAt"
    type = "S"
  }

  global_secondary_index {
    name            = "GSI_CustomerLedger"
    hash_key        = "customerId"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Environment = var.environment
    Service     = "customer"
  }
}

resource "aws_dynamodb_table" "customer_notifications" {
  name         = "${local.table_prefix}-customer-notifications"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }

  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Environment = var.environment
    Service     = "customer"
  }
}

# ─── Search Index ───────────────────────────────────────────────────────

resource "aws_dynamodb_table" "search_index" {
  name         = "${local.table_prefix}-search-index"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }
  attribute {
    name = "GSI1PK"
    type = "S"
  }
  attribute {
    name = "GSI1SK"
    type = "S"
  }
  attribute {
    name = "GSI2PK"
    type = "S"
  }
  attribute {
    name = "GSI2SK"
    type = "S"
  }

  global_secondary_index {
    name            = "GSI1"
    hash_key        = "GSI1PK"
    range_key       = "GSI1SK"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "GSI2"
    hash_key        = "GSI2PK"
    range_key       = "GSI2SK"
    projection_type = "KEYS_ONLY"
  }

  tags = {
    Environment = var.environment
    Service     = "search"
  }
}
