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
    cf_name           = string
    web_acl_arn       = string
    root_object       = string
    associate_domains = list(string)
    bucket_name       = string
  })
  default = {
    cf_name           = "<project>-cf-<stage>"
    web_acl_arn       = ""
    root_object       = "index.html"
    associate_domains = ["a.example.com", "b.example.com"]
    bucket_name       = "<application>-web-<environment>"
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
