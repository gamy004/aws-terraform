variable "vpc_id" {
  description = "Value of the vpc id for the database"
  type        = string
}

variable "configs" {
  description = "Value of the configurations for the database"
  type = object({
    name                = string
    port                = number
    monitoring_role_arn = string
    min_capacity        = number
    max_capacity        = number
    num_instances       = number
    security_group_ids  = list(string)
    subnet_group_name   = string
  })
  default = {
    name                = "db"
    port                = 5432
    monitoring_role_arn = ""
    min_capacity        = 0.5
    max_capacity        = 1
    num_instances       = 1
    security_group_ids  = []
    subnet_group_name   = ""
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
