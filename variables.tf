variable "domain_name" {
  description = "Value of the domain name associated with the infrastructure"
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

variable "db_configs" {
  type = object({
    name               = string
    port               = number
    min_capacity       = number
    max_capacity       = number
    num_instances      = number
    subnet_group_name  = string
  })
  default = {
    name               = "db"
    port               = 5432
    min_capacity       = 0.5
    max_capacity       = 1
    num_instances      = 1
    subnet_group_name  = ""
  }
}

variable "sg_configs" {
  type = object({})
  default = {}
}

variable "lb_configs" {
  type = object({})
  default = {}
}