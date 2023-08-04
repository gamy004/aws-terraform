variable "region" {
  description = "Value of the region for the external load balancer"
  type        = string
}

variable "vpc_id" {
  description = "Value of the vpc id for the external load balancer"
  type        = string
}

variable "certificate_arn" {
  description = "Value of the certificate arn for the external load balancer"
  type        = string
}

variable "configs" {
  description = "Value of the configurations for the load balancer"
  type = object({
    name                         = string
    target_group_name            = string
    subnet_ids                   = list(string)
    security_group_ids           = list(string)
    internal_public_alb_dns_name = string
  })
  default = {
    name                         = "<project>-external-alb-<stage>"
    target_group_name            = "<project>-external-alb-tg-<stage>"
    subnet_ids                   = []
    security_group_ids           = []
    internal_public_alb_dns_name = ""
  }
}

variable "tags" {
  description = "Value of the tags for the external load balancer"
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
