# variable "region" {
#   description = "Value of the region for the service"
#   type        = string
# }

# variable "vpc_id" {
#   description = "Value of the vpc id for the service"
#   type        = string
# }

variable "configs" {
  description = "Value of the configurations for the authentication"
  type = object({
    user_pool_name           = string
    password_minimum_length  = number
    username_attributes      = list(string)
    auto_verified_attributes = list(string)
    required_user_attributes = list(string)
    lambda_configs           = any
    clients = map(object({
      access_token_validity  = number
      id_token_validity      = number
      refresh_token_validity = number
      generate_secret        = bool
      token_validity_units = object({
        access_token  = string
        id_token      = string
        refresh_token = string
      })
      explicit_auth_flows = list(string)
    }))
    tags = object({
      Environment = string
    })
  })
  default = {
    user_pool_name           = "<project>-user-pool-<environment>"
    password_minimum_length  = 6
    username_attributes      = ["email"]
    auto_verified_attributes = ["email"]
    required_user_attributes = ["email"]
    lambda_configs = {
      user_migration_lambda_arn                 = ""
      define_auth_challenge_lambda_arn          = ""
      create_auth_challenge_lambda_arn          = ""
      verify_auth_challenge_response_lambda_arn = ""
    }
    clients = {
      "<application>-service-<environment>" = {
        access_token_validity  = 24
        id_token_validity      = 24
        refresh_token_validity = 90
        generate_secret        = true
        token_validity_units = {
          access_token  = "hours"
          id_token      = "hours"
          refresh_token = "days"
        }
        explicit_auth_flows = [
          "ALLOW_REFRESH_TOKEN_AUTH",
          "ALLOW_USER_PASSWORD_AUTH",
          "ALLOW_ADMIN_USER_PASSWORD_AUTH"
        ]
      }
    }
    tags = {
      Environment = "<environment>"
    }
  }
}

variable "tags" {
  description = "Value of the tags for the api gateway"
  type = object({
    Project   = string
    Stage     = string
    Terraform = bool
  })
  default = {
    Project   = ""
    Stage     = ""
    Terraform = true
  }
}
