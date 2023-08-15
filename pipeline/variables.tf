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
    # cloudfront_dist_id                = string
    cloudfront_invalidation_role_arn = string
    s3_artifact_bucket_name          = string
    review_subnet_ids                = list(string)
    review_security_group_ids        = list(string)
    # subnet_ids         = list(string)
    # security_group_ids = list(string)
    # target_group_arns  = list(string)
    service_pipeline_configs = list(object({
      repo_name         = string
      service_name      = string
      ci_build_name     = string
      review_build_name = string
      pipeline_name     = string
      build             = bool
      deploy            = bool
      review            = bool
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
    web_pipeline_configs = list(object({
      repo_name         = string
      bucket_name       = string
      ci_build_name     = string
      review_build_name = string
      pipeline_name     = string
      build             = bool
      deploy            = bool
      review            = bool
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
      provider           = string
      id                 = string
      env_branch_mapping = map(string)
    }))
  })
  default = {
    cluster_name                      = "<project>-cluster-<stage>"
    parameter_store_access_policy_arn = ""
    s3_access_policy_arn              = ""
    # cloudfront_dist_id                = ""
    cloudfront_invalidation_role_arn = ""
    s3_artifact_bucket_name          = "<project>-artifacts"
    review_subnet_ids                = []
    review_security_group_ids        = []
    service_pipeline_configs = [{
      repo_name         = "<application>-service"
      service_name      = "<application>-service-<environment>"
      ci_build_name     = "<project>-<application>-service-ci-codebuild-<environment>"
      review_build_name = "<project>-<application>-service-review-codebuild-<environment>"
      pipeline_name     = "<project>-<application>-service-codepipeline-<environment>"
      build             = true
      deploy            = true
      review            = true
      # s3_bucket_name    = "<application>-<environment>-<account>"
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
    web_pipeline_configs = [{
      repo_name         = "<application>-web"
      bucket_name       = "<application>-web-<environment>"
      ci_build_name     = "<project>-<application>-web-ci-codebuild-<environment>"
      review_build_name = "<project>-<application>-web-review-codebuild-<environment>"
      pipeline_name     = "<project>-<application>-web-codepipeline-<environment>"
      build             = true
      deploy            = false
      review            = true
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
        env_branch_mapping = {
          "dev" = "develop"
        }
      }
      "<application>-web" = {
        provider = "Bitbucket"
        id       = "<project>/<application>-web"
        env_branch_mapping = {
          "dev" = "develop"
        }
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
