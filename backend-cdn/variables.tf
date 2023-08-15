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

variable "certificate_arn" {
  description = "Value of the certificate arn for the api gateway"
  type        = string
}

variable "configs" {
  description = "Value of the configurations for the api gateway"
  type = object({
    cf_name     = string
    web_acl_arn = string

    associate_domains = list(string)
    default_origin    = any
  })
  default = {
    cf_name           = "<project>-cf-<stage>"
    web_acl_arn       = ""
    associate_domains = ["a.example.com", "b.example.com"]
    default_origin = {
      name   = "origin-domain"
      domain = "a.example.com"
      custom_origin_config = {
        http_port                = 80
        https_port               = 443
        origin_keepalive_timeout = 5
        origin_protocol_policy   = "https-only"
        origin_read_timeout      = 30
        origin_ssl_protocols = [
          "SSLv3",
          "TLSv1",
        ]
      }
    }
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
