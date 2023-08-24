variable "vpc_id" {
  description = "Value of the vpc id for the load balancer"
  type        = string
}

variable "certificate_arn" {
  description = "Value of the certificate arn for the load balancer"
  type        = string
}

variable "configs" {
  description = "Value of the configurations for the load balancer"
  type = object({
    public_alb_name                = string
    private_alb_name               = string
    private_nlb_name               = string
    public_alb_target_group_name   = string
    private_nlb_target_group_name  = string
    public_alb_security_group_ids  = list(string)
    private_alb_security_group_ids = list(string)
    public_alb_subnet_ids          = list(string)
    private_alb_subnet_ids         = list(string)
    private_nlb_subnet_ids         = list(string)
    api_gateway_vpc_endpoint_ids   = list(string)
    api_configs = list(object({
      host_header_name  = string
      target_group_name = string
      tags = object({
        Environment = string
        Application = string
      })
    }))
  })
  default = {
    public_alb_name                = "<project>-alb-<stage>"
    public_alb_target_group_name   = "<project>-api-gw-tg-<stage>"
    private_alb_name               = "<project>-nonexpose-alb-<stage>"
    private_nlb_name               = "<project>-nonexpose-nlb-<stage>"
    private_nlb_target_group_name  = "<project>-nonexpose-nlb-tg-<stage>"
    public_alb_security_group_ids  = []
    private_alb_security_group_ids = []
    public_alb_subnet_ids          = []
    private_alb_subnet_ids         = []
    private_nlb_subnet_ids         = []
    api_gateway_vpc_endpoint_ids   = []
    api_configs = [{
      host_header_name  = "<environment>-api-<application>.<domain>"
      target_group_name = "<application>-<service>-tg.<environment>"
      tags = {
        Environment = "<environment>"
        Application = "<>"
      }
    }]
  }
}

variable "tags" {
  description = "Value of the tags for the load balancer"
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
