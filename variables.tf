variable "vpc_name" {
  description = "Value of the vpc name for the infrastructure"
  type        = string
}

variable "stage" {
  description = "Value of the stage for the infrastructure"
  type        = string
  default     = "default"
}

variable "db" {
  type = object({
    name               = string
    monitoring_role_arn = string
    security_group_ids = list(string)
    min_capacity       = number
    max_capacity       = number
    num_instances      = number
    database_subnet_group_name = string
  })
  default = {
    name               = "db"
    monitoring_role_arn = ""
    security_group_ids = []
    min_capacity       = 0.5
    max_capacity       = 1
    num_instances      = 1
    database_subnet_group_name = ""
  }
}

# variable "instance_name" {
#   description = "Value of the Name tag for the EC2 instance"
#   type        = string
#   default     = "example-instance"
# }