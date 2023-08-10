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
    cloudfront_dist_id                = string
    cloudfront_invalidation_role_arn  = string
    s3_artifact_bucket_name           = string
    review_subnet                     = string
    # subnet_ids         = list(string)
    # security_group_ids = list(string)
    # target_group_arns  = list(string)
    service_configs = list(object({
      repo_name         = string
      service_name      = string
      ci_build_name     = string
      review_build_name = string
      s3_bucket_name    = string
      environment_variables = object({
        build = map(
          object({
            type  = string
            value = any
          })
        )
        review = map(
          object({
            type  = string
            value = any
          })
        )
      })
      tags = object({
        Environment = string
        Application = string
      })
    }))
    repo_configs = map(object({
      provider = string
      id       = string
    }))
  })
  default = {
    cluster_name                      = "<project>-cluster-<stage>"
    parameter_store_access_policy_arn = ""
    s3_access_policy_arn              = ""
    cloudfront_dist_id                = ""
    cloudfront_invalidation_role_arn  = ""
    s3_artifact_bucket_name           = "<project>-artifacts"
    review_subnet                     = ""
    service_configs = [{
      repo_name         = "<application>-service"
      service_name      = "<application>-service-<environment>"
      ci_build_name     = "<project>-<application>-ci-codebuild-<environment>"
      review_build_name = "<project>-<application>-review-codebuild-<environment>"
      pipeline_name     = "<project>-<application>-codepipeline-<environment>"
      s3_bucket_name    = "<application>-<environment>-<account>"
      environment_variables = {
        build = {
          AWS_DEFAULT_REGION = {
            type  = "PLAINTEXT"
            value = "ap-southeast-1"
          }
        }
        review = {
          AWS_DEFAULT_REGION = {
            type  = "PLAINTEXT"
            value = "ap-southeast-1"
          }
        }
      }
      tags = {
        Environment = "<environment>"
        Application = "<application>"
      }
    }]
    repo_configs = {
      "<application>-service" = {
        provider = "Bitbucket"
        id       = "<project>/<application>-service"
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
