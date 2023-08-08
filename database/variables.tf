variable "vpc_id" {
  description = "Value of the vpc id for the database"
  type        = string
}

variable "security_group_ids" {
  description = "Value of the security group ids for the database"
  type        = list(string)
}

variable "subnet_group_name" {
  description = "Value of the subnet group name for the database"
  type        = string
}

variable "monitoring_role_arn" {
  description = "Value of the monitoring role arn for the database"
  type        = string
}

variable "configs" {
  description = "Value of the configurations for the database"
  type = map(object({
    engine         = string
    engine_version = string
    port           = number
    min_capacity   = number
    max_capacity   = number
    num_instances  = number
  }))
  default = {
    project-dev = {
      port           = 5432
      engine         = "aurora-postgresql"
      engine_version = "15.3"
      min_capacity   = 0.5
      max_capacity   = 1
      num_instances  = 1
    }
  }
}

variable "tags" {
  description = "Value of the tags for the database"
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
