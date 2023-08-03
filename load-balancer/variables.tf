variable "region" {
  description = "Value of the region for the load balancer"
  type        = string
}

variable "network_vpc_id" {
  description = "Value of the vpc id for the load balancer in network account"
  type        = string
}

variable "workload_vpc_id" {
  description = "Value of the vpc id for the load balancer in workload account"
  type        = string
}

variable "network_certificate_arn" {
  description = "Value of the certificate arn for the load balancer in network account"
  type        = string
}

variable "workload_certificate_arn" {
  description = "Value of the certificate arn for the load balancer in workload account"
  type        = string
}

variable "configs" {
  description = "Value of the configurations for the load balancer"
  type = object({
    external_alb_name               = string
    external_alb_target_group_name  = string
    public_alb_name                 = string
    private_alb_name                = string
    private_nlb_name                = string
    private_nlb_target_group_name   = string
    external_alb_security_group_ids = list(string)
    public_alb_security_group_ids   = list(string)
    private_alb_security_group_ids  = list(string)
    external_alb_subnet_ids         = list(string)
    public_alb_subnet_ids           = list(string)
    private_alb_subnet_ids          = list(string)
    private_nlb_subnet_ids          = list(string)
    api_domain                      = string
  })
  default = {
    external_alb_name               = "<project>-external-alb-<stage>"
    external_alb_target_group_name  = "<project>-external-alb-tg-<stage>"
    public_alb_name                 = "<project>-alb-<stage>"
    private_alb_name                = "<project>-nonexpose-alb-<stage>"
    private_nlb_name                = "<project>-nonexpose-nlb-<stage>"
    private_nlb_target_group_name   = "<project>-nonexpose-nlb-tg-<stage>"
    external_alb_security_group_ids = []
    public_alb_security_group_ids   = []
    private_alb_security_group_ids  = []
    external_alb_subnet_ids         = []
    public_alb_subnet_ids           = []
    private_alb_subnet_ids          = []
    private_nlb_subnet_ids          = []
    api_domain                      = "<stage>-api-<project>.<domain>"
  }
}

variable "tags" {
  description = "Value of the tags for the load balancer"
  type = object({
    Project     = string
    Environment = string
    Terraform   = bool
  })
  default = {
    Project     = ""
    Environment = ""
    Terraform   = true
  }
}
