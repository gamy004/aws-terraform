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
    minimum_length = try(var.configs.password_minimum_length, 6)
  }

  auto_verified_attributes = try(var.configs.required_user_attributes, ["email"])
  username_attributes      = try(var.configs.username_attributes, ["email"])
  user_attribute_update_settings = {
    attributes_require_verification_before_update = try(var.configs.required_user_attributes, ["email"])
  }
  #   dynamic "user_attribute_update_settings" {
  #     for_each = length(var.configs.required_user_attributes) > 0 ? [var.configs.required_user_attributes] : []

  #     content {
  #       attributes_require_verification_before_update = [
  #         for attr in each.value : attr
  #       ]
  #     }
  #   }

  tags = merge(var.tags, { Name : var.configs.user_pool_name })
}
