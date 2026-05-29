# =============================================================================
# S3, SQS, SNS, EventBridge, Secrets Manager, SSM — Terraform Resources
# =============================================================================

# ─── S3 Buckets ─────────────────────────────────────────────────────────

resource "aws_s3_bucket" "barcode_labels" {
  bucket = "${var.stack_name}-barcode-labels"
  tags = {
    Environment = var.environment
    Service     = "barcode"
  }
}

resource "aws_s3_bucket" "uploads" {
  bucket = "${var.stack_name}-uploads"
  tags = {
    Environment = var.environment
    Service     = "storage"
  }
}

resource "aws_s3_bucket" "exports" {
  bucket = "${var.stack_name}-exports"
  tags = {
    Environment = var.environment
    Service     = "reporting"
  }
}

# ─── SQS Queues ─────────────────────────────────────────────────────────

resource "aws_sqs_queue" "email_dlq" {
  name                      = "${var.stack_name}-email-notifications-dlq"
  message_retention_seconds = 1209600 # 14 days
  tags = {
    Environment = var.environment
    Service     = "notifications"
  }
}

resource "aws_sqs_queue" "email_notifications" {
  name                       = "${var.stack_name}-email-notifications"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400 # 1 day

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.email_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Environment = var.environment
    Service     = "notifications"
  }
}

resource "aws_sqs_queue" "audit_events" {
  name                       = "${var.stack_name}-audit-events"
  visibility_timeout_seconds = 30
  tags = {
    Environment = var.environment
    Service     = "audit"
  }
}

resource "aws_sqs_queue" "trial_provisioning" {
  name                       = "${var.stack_name}-trial-provisioning"
  visibility_timeout_seconds = 120
  tags = {
    Environment = var.environment
    Service     = "provisioning"
  }
}

# ─── SNS Topics ─────────────────────────────────────────────────────────

resource "aws_sns_topic" "tenant_events" {
  name = "${var.stack_name}-tenant-events"
  tags = {
    Environment = var.environment
    Service     = "tenants"
  }
}

resource "aws_sns_topic" "billing_events" {
  name = "${var.stack_name}-billing-events"
  tags = {
    Environment = var.environment
    Service     = "billing"
  }
}

resource "aws_sns_topic" "user_events" {
  name = "${var.stack_name}-user-events"
  tags = {
    Environment = var.environment
    Service     = "users"
  }
}

resource "aws_sns_topic" "alerts" {
  name = "${var.stack_name}-alerts"
  tags = {
    Environment = var.environment
    Service     = "ops"
  }
}

# SNS → SQS Subscription (email notifications)
resource "aws_sns_topic_subscription" "user_events_to_email" {
  topic_arn = aws_sns_topic.user_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.email_notifications.arn
}

# ─── EventBridge ────────────────────────────────────────────────────────

resource "aws_cloudwatch_event_bus" "main" {
  name = "${var.stack_name}-main-bus"
  tags = {
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_rule" "subscription_lifecycle" {
  name           = "subscription-lifecycle"
  event_bus_name = aws_cloudwatch_event_bus.main.name

  event_pattern = jsonencode({
    source      = ["dukan.billing"]
    detail-type = ["SubscriptionCreated", "SubscriptionCancelled", "SubscriptionExpired"]
  })

  tags = {
    Environment = var.environment
    Service     = "billing"
  }
}

resource "aws_cloudwatch_event_rule" "tenant_onboarding" {
  name           = "tenant-onboarding"
  event_bus_name = aws_cloudwatch_event_bus.main.name

  event_pattern = jsonencode({
    source      = ["dukan.tenants"]
    detail-type = ["TenantCreated", "TenantDeleted"]
  })

  tags = {
    Environment = var.environment
    Service     = "tenants"
  }
}

# EventBridge → SQS targets
resource "aws_cloudwatch_event_target" "subscription_to_sqs" {
  rule           = aws_cloudwatch_event_rule.subscription_lifecycle.name
  event_bus_name = aws_cloudwatch_event_bus.main.name
  target_id      = "subscription-to-audit"
  arn            = aws_sqs_queue.audit_events.arn
}

resource "aws_cloudwatch_event_target" "tenant_to_sqs" {
  rule           = aws_cloudwatch_event_rule.tenant_onboarding.name
  event_bus_name = aws_cloudwatch_event_bus.main.name
  target_id      = "tenant-to-provisioning"
  arn            = aws_sqs_queue.trial_provisioning.arn
}

# ─── Secrets Manager ───────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "jwt_signing_key" {
  name = "${var.stack_name}/jwt-signing-key"
  tags = {
    Environment = var.environment
    Service     = "auth"
  }
}

resource "aws_secretsmanager_secret_version" "jwt_signing_key" {
  secret_id = aws_secretsmanager_secret.jwt_signing_key.id
  secret_string = jsonencode({
    key = "local-dev-jwt-secret-256-bit-key-do-not-use-in-prod"
  })
}

resource "aws_secretsmanager_secret" "razorpay" {
  name = "${var.stack_name}/razorpay"
  tags = {
    Environment = var.environment
    Service     = "payments"
  }
}

resource "aws_secretsmanager_secret_version" "razorpay" {
  secret_id = aws_secretsmanager_secret.razorpay.id
  secret_string = jsonencode({
    key_id     = "rzp_test_LOCALDEV"
    key_secret = "localdev_secret_DONOTUSE"
  })
}

# ─── SSM Parameter Store ───────────────────────────────────────────────

resource "aws_ssm_parameter" "environment" {
  name  = "/${var.stack_name}/environment"
  type  = "String"
  value = var.environment
  tags = {
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "api_url" {
  name  = "/${var.stack_name}/api-url"
  type  = "String"
  value = "http://localhost:4566"
  tags = {
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "redis_url" {
  name  = "/${var.stack_name}/redis-url"
  type  = "String"
  value = "redis://redis:6379"
  tags = {
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "feature_flags" {
  name  = "/${var.stack_name}/feature-flags"
  type  = "String"
  value = jsonencode({
    enableWebSocket  = true
    enableBarcode    = true
    enableMarketplace = false
  })
  tags = {
    Environment = var.environment
  }
}
