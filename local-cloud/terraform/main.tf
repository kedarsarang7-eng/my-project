# =============================================================================
# Terraform — LocalStack Provider Configuration
# =============================================================================
# This Terraform config targets LocalStack, not real AWS.
# All resources are created locally via the LocalStack endpoint.
# =============================================================================

terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }

  # Local backend — no remote state for local dev
  backend "local" {
    path = "terraform.tfstate"
  }
}

# ─── Provider ───────────────────────────────────────────────────────────

provider "aws" {
  region                      = var.aws_region
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    apigateway       = var.localstack_endpoint
    apigatewayv2     = var.localstack_endpoint
    cloudwatch       = var.localstack_endpoint
    cloudwatchlogs   = var.localstack_endpoint
    cognitoidp       = var.localstack_endpoint
    dynamodb         = var.localstack_endpoint
    events           = var.localstack_endpoint
    iam              = var.localstack_endpoint
    lambda           = var.localstack_endpoint
    s3               = var.localstack_endpoint
    secretsmanager   = var.localstack_endpoint
    ses              = var.localstack_endpoint
    sns              = var.localstack_endpoint
    sqs              = var.localstack_endpoint
    ssm              = var.localstack_endpoint
    stepfunctions    = var.localstack_endpoint
    sts              = var.localstack_endpoint
  }
}
