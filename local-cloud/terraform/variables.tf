# =============================================================================
# Terraform Variables
# =============================================================================

variable "aws_region" {
  description = "AWS region for LocalStack"
  type        = string
  default     = "ap-south-1"
}

variable "localstack_endpoint" {
  description = "LocalStack gateway endpoint"
  type        = string
  default     = "http://localhost:4566"
}

variable "stack_name" {
  description = "Stack name prefix for all resources"
  type        = string
  default     = "dukan-saas-dev"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
