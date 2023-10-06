variable "project_name" {
  description = "Value of the project name associated with the infrastructure"
  type        = string
}

variable "domain_name" {
  description = "Value of the domain name associated with the infrastructure"
  type        = string
}

variable "aws_region" {
  description = "Value of the aws region for the infrastructure"
  type        = string
}

variable "workload_account_id" {
  description = "Value of the workload account id for the infrastructure"
  type        = string
}

variable "network_account_id" {
  description = "Value of the network account id for the infrastructure"
  type        = string
}

variable "stage" {
  description = "Value of the stage for the infrastructure"
  type        = string
  default     = "default"
}

variable "environments" {
  description = "List of value of the environment names for the infrastructure"
  type        = list(string)
  default     = ["env-1", "env-2"]
}

variable "applications" {
  description = "List of value of the application names for the infrastructure"
  type        = list(string)
  default     = ["app-1", "app-2"]
}

variable "db_configs" {
  type = object({
    instances         = map(any)
    subnet_group_name = string
  })
  default = {
    instances = {
      ct4life = {
        dev = {
          port          = 5432
          min_capacity  = 0.5
          max_capacity  = 1
          num_instances = 1
        }
      }
    }
    subnet_group_name = ""
  }
}

variable "sg_configs" {
  type    = any
  default = {}
}

variable "lb_configs" {
  type    = any
  default = {}
}

variable "backend_configs" {
  type    = any
  default = {}
}

variable "frontend_configs" {
  type    = any
  default = {}
}

variable "build_configs" {
  type = object({
    environment_variables = object({
      # all    = any
      pull   = any
      build  = any
      review = any
    }),
    ecr_configs     = any
    pipeline_stages = any
  })
  default = {
    environment_variables = {
      # all    = {}
      pull   = {}
      build  = {}
      review = {}
    }
    ecr_configs = {
      "<application>-service-<environment>" = {
        aloow_pull_cross_account = true
        allow_pull_principle_arns = {
          AWS = "arn"
        }
      }
    }
    pipeline_stages = {
      source = {
        "<application>-service-<environment>" = {
          provider = "CodeStarSourceConnection"
        }
      }
      pull = {
        "<application>-service-<environment>" = {
          codebuild_name = ""
        }
      }
      build = {
        "<application>-service-<environment>" = true
      }
      deploy = {
        "<application>-service-<environment>" = true
      }
      review = {
        "<application>-service-<environment>" = true
      }
    }
  }
}

variable "repo_configs" {
  type    = any
  default = {}
}

variable "authentication_configs" {
  type = any
  default = {
    dev = {
      lambda_configs = {
        user_migration_lambda_arn = ""
      }
      client_configs = {
        "<application>-service" = {
          generate_secret = true
          refresh_token_validity = {
            duration = 30
            unit     = "days"
          }
          access_token_validity = {
            duration = 30
            unit     = "minutes"
          }
          id_token_validity = {
            duration = 1
            unit     = "hours"
          }
          explicit_auth_flows = [
            "ALLOW_REFRESH_TOKEN_AUTH",
            "ALLOW_USER_PASSWORD_AUTH",
            "ALLOW_USER_SRP_AUTH",
            "ALLOW_ADMIN_USER_PASSWORD_AUTH"
          ]
        }
      }
    }
    uat = {
      lambda_configs = {
        user_migration_lambda_arn = ""
      }
    }
  }
}

variable "parameter_store_configs" {
  type = any
  default = {
    kms_key_id = ""
    parameters = {
      "<application>-web-<stage>" = {
        secure_param = {
          name  = "secure-param"
          type  = "SecureString"
          value = "1234"
        }
        normal_param = {
          name  = "normal-param"
          type  = "String"
          value = "1234"
        }
      }
    }
  }
}

variable "automation_configs" {
  type = object({
    source_account_id = string
    s3_bucket_name    = string
    assume_role_arn   = string
    projects          = list(string)
    pipeline_mappings = map(string)
  })

  default = {
    source_account_id = ""
    s3_bucket_name    = ""
    assume_role_arn   = ""
    projects          = []
    pipeline_mappings = {
      "<application>-web-<environment>" = "<application>-web-<environment>"
    }
  }
}
