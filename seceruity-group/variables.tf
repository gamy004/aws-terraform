variable "network_vpc_id" {
  description = "Value of the vpc id for the load balancer in network account"
  type        = string
}

variable "workload_vpc_id" {
  description = "Value of the vpc id for the load balancer in workload account"
  type        = string
}

variable "configs" {
  description = "Value of the configurations for the database"
  type = object({
    secure_security_group_name       = string
    app_security_group_name          = string
    external_alb_security_group_name = string
    public_alb_security_group_name   = string
    private_alb_security_group_name  = string
    db_ports                         = list(number)
  })
  default = {
    secure_security_group_name       = "<project>-secure-sg-<stage>"
    app_security_group_name          = "<project>-app-sg-<stage>"
    external_alb_security_group_name = "<project>-external-alb-sg-<stage>"
    public_alb_security_group_name   = "<project>-alb-sg-<stage>"
    private_alb_security_group_name  = "<project>-nonexpose-alb-sg-<stage>"
    db_ports                         = [3306, 5432]
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
