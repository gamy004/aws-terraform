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
      build  = any
      review = any
    }),
    pipeline_stages = any
  })
  default = {
    environment_variables = {
      # all    = {}
      build  = {}
      review = {}
    }
    pipeline_stages = {
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
    }
    uat = {
      lambda_configs = {
        user_migration_lambda_arn = ""
      }
    }
  }
}

