variable "region" {
  description = "Value of the region for the api gateway"
  type        = string
}

variable "vpc_id" {
  description = "Value of the vpc id for the api gateway"
  type        = string
}

variable "domain_name" {
  description = "Value of the domain name associated with the api gateway"
  type        = string
}

variable "cloudwatch_role_arn" {
  description = "Value of the cloudwatch role arn for the api gateway"
  type        = string
}

variable "certificate_arn" {
  description = "Value of the certificate arn for the api gateway"
  type        = string
}

variable "configs" {
  description = "Value of the configurations for the api gateway"
  type = object({
    name                         = string
    vpc_link_name                = string
    private_nlb_dns_name         = string
    private_nlb_target_group_arn = string
    vpc_endpoint_ids             = list(string)
    api_configs = list(object({
      host_header_name = string
      api_gateway_name = string
      allowed_origins  = list(string)
      tags = object({
        Environment = string
        Application = string
      })
    }))
  })
  default = {
    name                         = "<project>-api-gw-<stage>"
    vpc_link_name                = "<project>-vpclink-<stage>"
    private_nlb_dns_name         = ""
    private_nlb_target_group_arn = ""
    vpc_endpoint_ids             = []
    api_configs = [{
      host_header_name = "<environment>-api-<application>.<domain>"
      api_gateway_name = "<application>-api-gw-<environment>"
      allowed_origins  = ["<application>.domain.com"]
      tags = {
        Environment = "<environment>"
        Application = "<>"
      }
    }]
  }
}

variable "tags" {
  description = "Value of the tags for the api gateway"
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
