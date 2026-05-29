output "dynamodb_tables" {
  value = {
    auth_sessions          = aws_dynamodb_table.auth_sessions.name
    tenants                = aws_dynamodb_table.tenants.name
    users                  = aws_dynamodb_table.users.name
    billing                = aws_dynamodb_table.billing.name
    audit_logs             = aws_dynamodb_table.audit_logs.name
    customer_invoices      = aws_dynamodb_table.customer_invoices.name
    customer_ledger        = aws_dynamodb_table.customer_ledger.name
    customer_notifications = aws_dynamodb_table.customer_notifications.name
  }
}

output "sqs_queues" {
  value = {
    email_notifications = aws_sqs_queue.email_notifications.url
    email_dlq           = aws_sqs_queue.email_dlq.url
    audit_events        = aws_sqs_queue.audit_events.url
    trial_provisioning  = aws_sqs_queue.trial_provisioning.url
  }
}

output "sns_topics" {
  value = {
    tenant_events  = aws_sns_topic.tenant_events.arn
    billing_events = aws_sns_topic.billing_events.arn
    user_events    = aws_sns_topic.user_events.arn
    alerts         = aws_sns_topic.alerts.arn
  }
}

output "s3_buckets" {
  value = {
    barcode_labels = aws_s3_bucket.barcode_labels.id
    uploads        = aws_s3_bucket.uploads.id
    exports        = aws_s3_bucket.exports.id
  }
}

output "eventbridge_bus" {
  value = aws_cloudwatch_event_bus.main.name
}

output "step_function_arn" {
  value = aws_sfn_state_machine.trial_provisioning.arn
}
