resource "aws_cognito_user_pool" "this" {
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

  username_attributes      = try(var.configs.username_attributes, ["email"])
  auto_verified_attributes = try(var.configs.required_user_attributes, ["email"])
  user_attribute_update_settings {
    attributes_require_verification_before_update = try(var.configs.required_user_attributes, ["email"])
  }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "email"
    required                 = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "family_name"
    required                 = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "given_name"
    required                 = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "profile"
    required                 = false
    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "picture"
    required                 = false
    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
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

resource "aws_cognito_user_pool_client" "client" {
  for_each = var.configs.clients

  name = "${each.key}-client"

  prevent_user_existence_errors = "ENABLED"
  user_pool_id                  = aws_cognito_user_pool.this.id
  generate_secret               = each.value.generate_secret
  refresh_token_validity        = each.value.refresh_token_validity
  explicit_auth_flows           = each.value.explicit_auth_flows

}
