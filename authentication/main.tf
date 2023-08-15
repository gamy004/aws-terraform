resource "aws_cognito_user_pool" "pool" {
  name = var.configs.user_pool_name

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  password_policy {
    minimum_length = 6
  }

  tags = merge(var.tags, { Name : var.configs.user_pool_name })
}
