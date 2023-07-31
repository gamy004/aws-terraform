variable "stage" {
  description = "Value of the stage for the infrastructure"
  type        = string
  default     = "default"
}

variable "vpc" {
  type = object({
    id = string
    database_subnet_group_name = string
  })
  default = {
    id = ""
    database_subnet_group_name = ""
  }
}

variable "db" {
  type = object({
    name               = string
    security_group_ids = list(string)
    min_capacity       = number
    max_capacity       = number
  })
  default = {
    name               = "db"
    security_group_ids = []
    min_capacity       = 0.5
    max_capacity       = 1
  }
}

# variable "instance_name" {
#   description = "Value of the Name tag for the EC2 instance"
#   type        = string
#   default     = "example-instance"
# }