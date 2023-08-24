# variable "region" {
#   description = "Value of the region for the api gateway"
#   type        = string
# }

# variable "vpc_id" {
#   description = "Value of the vpc id for the api gateway"
#   type        = string
# }

# variable "domain_name" {
#   description = "Value of the domain name associated with the api gateway"
#   type        = string
# }

# variable "certificate_arn" {
#   description = "Value of the certificate arn for the api gateway"
#   type        = string
# }

variable "configs" {
  description = "Value of the configurations for the api gateway"
  type = object({
    frontend_waf_name        = string
    backend_waf_name         = string
    waf_ip_set_outbound_name = string
  })
  default = {
    frontend_waf_name        = "<project>-backend-waf-<stage>"
    backend_waf_name         = "<project>-frontend-waf-<stage>"
    waf_ip_set_outbound_name = "<project>-outbound-ip-set"
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
