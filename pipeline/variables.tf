variable "region" {
  description = "Value of the region for the service"
  type        = string
}

variable "vpc_id" {
  description = "Value of the vpc id for the service"
  type        = string
}

variable "configs" {
  description = "Value of the configurations for the service"
  type = object({
    cluster_name                      = string
    parameter_store_access_policy_arn = string
    s3_access_policy_arn              = string
    cloudfront_invalidation_role_arn  = string
    # subnet_ids         = list(string)
    # security_group_ids = list(string)
    # target_group_arns  = list(string)
    service_configs = list(object({
      service_name        = string
      pipeline_build_name = string
      tags = object({
        Environment = string
        Application = string
      })
    }))
  })
  default = {
    cluster_name                      = "<project>-cluster-<stage>"
    parameter_store_access_policy_arn = ""
    s3_access_policy_arn              = ""
    cloudfront_invalidation_role_arn  = ""
    # subnet_ids         = []
    # security_group_ids = []
    # target_group_arns  = []
    service_configs = [{
      service_name        = "<application>-service-<environment>"
      pipeline_build_name = "<project>-<application>-ci-codebuild-<environment>"
      tags = {
        Environment = "<environment>"
        Application = "<application>"
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
