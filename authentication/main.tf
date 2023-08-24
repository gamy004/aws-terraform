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
  auto_verified_attributes = try(var.configs.auto_verified_attributes, ["email"])

  # dynamic "user_attribute_update_settings" {
  #   for_each = length(var.configs.required_user_attributes) > 0 ? [var.configs.required_user_attributes] : []

  #   content {
  #     attributes_require_verification_before_update = user_attribute_update_settings.value
  #   }
  # }

  # user_attribute_update_settings {
  #   attributes_require_verification_before_update = try(var.configs.required_user_attributes, ["email"])
  # }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "email"
    required                 = contains(var.configs.required_user_attributes, "email")

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
    required                 = contains(var.configs.required_user_attributes, "family_name")

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
    required                 = contains(var.configs.required_user_attributes, "given_name")

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
      max_length = 2048
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
      max_length = 2048
    }
  }

  dynamic "lambda_config" {
    for_each = length(keys(var.configs.lambda_configs)) > 0 ? [var.configs.lambda_configs] : []

    content {
      user_migration = try(lambda_config.value.user_migration_lambda_arn, null)
    }
  }

  tags = merge(var.tags, { Name : var.configs.user_pool_name })
}

resource "aws_cognito_user_pool_client" "client" {
  for_each = var.configs.clients

  name = "${each.key}-client"

  prevent_user_existence_errors = "ENABLED"
  user_pool_id                  = aws_cognito_user_pool.this.id
  generate_secret               = each.value.generate_secret
  access_token_validity         = each.value.access_token_validity
  id_token_validity             = each.value.id_token_validity
  refresh_token_validity        = each.value.refresh_token_validity
  explicit_auth_flows           = each.value.explicit_auth_flows

  token_validity_units {
    access_token  = each.value.token_validity_units.access_token
    id_token      = each.value.token_validity_units.id_token
    refresh_token = each.value.token_validity_units.refresh_token
  }
}
