variable "region" {
  description = "Value of the region for the service"
  type        = string
}

variable "configs" {
  description = "Value of the configurations for the authentication"
  type = object({
    source_account_id = string
    s3_bucket_name    = string
    assume_role_arn   = string
    projects          = list(string)
    pipeline_arns     = map(string)
  })
  default = {
    source_account_id = ""
    s3_bucket_name    = ""
    assume_role_arn   = ""
    projects          = ["<application>-<environment>"]
    pipeline_arns = {
      "<application>-<environment>" = ""
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
