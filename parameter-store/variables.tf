variable "region" {
  description = "Value of the region for the service"
  type        = string
}

variable "kms_key_id" {
  description = "Value of the kms key id for the parameter store"
  type        = string
}

# variable "vpc_id" {
#   description = "Value of the vpc id for the service"
#   type        = string
# }

variable "configs" {
  description = "Value of the configurations for the authentication"
  type = list(object({
    prefix = string
    parameters = map(object({
      suffix = string
      name   = string
      type   = string
      value  = string
    }))
    tags = object({
      Application = string
      Environment = string
    })
  }))
  default = [
    {
      prefix = "<project>/<environment>"
      parameters = {
        secure_param = {
          suffix = "web"
          name   = "secure-param"
          type   = "SecureString"
          value  = "1234"
        }
        normal_param = {
          suffix = "web"
          name   = "normal-param"
          type   = "String"
          value  = "1234"
        }
      }
      tags = {
        Application = "<application>"
        Environment = "<environment>"
      }
    }
  ]
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
