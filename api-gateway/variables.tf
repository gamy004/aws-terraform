variable "vpc_id" {
  description = "Value of the vpc id for the api gateway"
  type        = string
}

variable "domain_name" {
  description = "Value of the domain name associated with the api gateway"
  type        = string
}

variable "certificate_arn" {
  description = "Value of the certificate arn for the api gateway"
  type        = string
}

variable "configs" {
  description = "Value of the configurations for the api gateway"
  type = object({
    name                            = string
    vpc_link_name                   = string
    public_alb_http_tcp_listern_arn = string
  })
  default = {
    name                            = "<project>-api-gw-<stage>"
    vpc_link_name                   = "<project>-vpclink-<stage>"
    public_alb_http_tcp_listern_arn = ""
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
