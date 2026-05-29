# Step Functions — Trial Provisioning Workflow
resource "aws_sfn_state_machine" "trial_provisioning" {
  name     = "${var.stack_name}-trial-provisioning"
  role_arn = "arn:aws:iam::000000000000:role/stepfunctions-role"

  definition = jsonencode({
    Comment = "Trial tenant provisioning workflow"
    StartAt = "ValidateTenant"
    States = {
      ValidateTenant = {
        Type     = "Task"
        Resource = "arn:aws:states:::dynamodb:getItem"
        Parameters = {
          TableName = "${var.stack_name}-tenants"
          Key       = { tenantId = { "S.$" = "$.tenantId" } }
        }
        ResultPath = "$.tenant"
        Next       = "CheckTenantExists"
      }
      CheckTenantExists = {
        Type = "Choice"
        Choices = [{
          Variable     = "$.tenant.Item"
          IsPresent    = true
          Next         = "ProvisionResources"
        }]
        Default = "TenantNotFound"
      }
      ProvisionResources = {
        Type     = "Parallel"
        Branches = [
          {
            StartAt = "CreateDefaultUser"
            States = {
              CreateDefaultUser = {
                Type     = "Task"
                Resource = "arn:aws:states:::dynamodb:putItem"
                Parameters = {
                  TableName = "${var.stack_name}-users"
                  Item = {
                    "tenantId#userId" = { "S.$" = "States.Format('{}#default-admin', $.tenantId)" }
                    email             = { "S.$" = "$.adminEmail" }
                    tenantId          = { "S.$" = "$.tenantId" }
                    "role#userId"     = { S = "superadmin#default-admin" }
                    role              = { S = "superadmin" }
                    status            = { S = "active" }
                  }
                }
                End = true
              }
            }
          },
          {
            StartAt = "CreateTrialSubscription"
            States = {
              CreateTrialSubscription = {
                Type     = "Task"
                Resource = "arn:aws:states:::dynamodb:putItem"
                Parameters = {
                  TableName = "${var.stack_name}-billing"
                  Item = {
                    tenantId = { "S.$" = "$.tenantId" }
                    SK       = { S = "SUB" }
                    plan     = { S = "trial" }
                    status   = { S = "trial" }
                    seats    = { N = "1" }
                  }
                }
                End = true
              }
            }
          }
        ]
        Next = "SendWelcomeEmail"
      }
      SendWelcomeEmail = {
        Type     = "Task"
        Resource = "arn:aws:states:::sqs:sendMessage"
        Parameters = {
          QueueUrl    = "http://localhost:4566/000000000000/${var.stack_name}-email-notifications"
          MessageBody = {
            "type"      = "WELCOME"
            "tenantId.$" = "$.tenantId"
            "email.$"    = "$.adminEmail"
          }
        }
        Next = "AuditLog"
      }
      AuditLog = {
        Type     = "Task"
        Resource = "arn:aws:states:::dynamodb:putItem"
        Parameters = {
          TableName = "${var.stack_name}-audit-logs"
          Item = {
            tenantId = { "S.$" = "$.tenantId" }
            SK       = { S = "TRIAL_PROVISIONED" }
            action   = { S = "TRIAL_PROVISIONED" }
          }
        }
        End = true
      }
      TenantNotFound = {
        Type  = "Fail"
        Error = "TenantNotFound"
        Cause = "Tenant does not exist"
      }
    }
  })
}
