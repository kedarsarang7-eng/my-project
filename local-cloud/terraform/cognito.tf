resource "aws_cognito_user_pool" "main" {
  name = "${var.stack_name}-user-pool"
  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
  }
  auto_verified_attributes = ["email"]
  username_attributes      = ["email"]
  schema {
    name = "email"; attribute_data_type = "String"; mutable = true; required = true
    string_attribute_constraints { min_length = 1; max_length = 256 }
  }
  schema {
    name = "tenantId"; attribute_data_type = "String"; mutable = true
    string_attribute_constraints { min_length = 1; max_length = 64 }
  }
  schema {
    name = "role"; attribute_data_type = "String"; mutable = false
    string_attribute_constraints { min_length = 1; max_length = 32 }
  }
  tags = { Environment = var.environment, Service = "auth" }
}

resource "aws_cognito_user_pool_client" "app" {
  name = "${var.stack_name}-app-client"
  user_pool_id = aws_cognito_user_pool.main.id
  generate_secret = false
  explicit_auth_flows = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
}

resource "aws_cognito_user_pool_client" "admin" {
  name = "${var.stack_name}-admin-client"
  user_pool_id = aws_cognito_user_pool.main.id
  generate_secret = false
  explicit_auth_flows = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
}

resource "aws_cognito_user_pool_client" "mobile" {
  name = "${var.stack_name}-mobile-client"
  user_pool_id = aws_cognito_user_pool.main.id
  generate_secret = false
  explicit_auth_flows = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
}

output "cognito_user_pool_id" { value = aws_cognito_user_pool.main.id }
output "cognito_app_client_id" { value = aws_cognito_user_pool_client.app.id }
output "cognito_admin_client_id" { value = aws_cognito_user_pool_client.admin.id }
output "cognito_mobile_client_id" { value = aws_cognito_user_pool_client.mobile.id }
