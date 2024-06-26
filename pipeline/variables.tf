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
      repo_name             = string
      source_provider       = string
      source_s3_bucket_name = string
      source_s3_object_key  = string
      service_name          = string
      ci_build_name         = string
      review_build_name     = string
      codebuild_image_config = object({
        compute_type = string
        image        = string
        type         = string
        buildspec    = string
      })
      pull_build_name           = string
      pipeline_name             = string
      allow_pull_cross_account  = bool
      allow_pull_principle_arns = any
      pull                      = bool
      build                     = bool
      deploy                    = bool
      review                    = bool
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
        pull = map(
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
      repo_name             = string
      source_provider       = string
      source_s3_bucket_name = string
      source_s3_object_key  = string
      bucket_name           = string
      ci_build_name         = string
      review_build_name     = string
      codebuild_image_config = object({
        compute_type = string
        image        = string
        type         = string
        buildspec    = string
      })
      pull_build_name           = string
      pipeline_name             = string
      allow_pull_cross_account  = bool
      allow_pull_principle_arns = any
      pull                      = bool
      build                     = bool
      deploy                    = bool
      review                    = bool
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
        pull = map(
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
      repo_name             = "<application>-service"
      source_provider       = "CodeStarSourceConnection"
      source_s3_bucket_name = ""
      source_s3_object_key  = ""
      service_name          = "<application>-service-<environment>"
      ci_build_name         = "<project>-<application>-service-ci-codebuild-<environment>"
      review_build_name     = "<project>-<application>-service-review-codebuild-<environment>"
      codebuild_image_config = {
        compute_type = "BUILD_GENERAL1_SMALL"
        image        = "aws/codebuild/standard:7.0"
        type         = "LINUX_CONTAINER"
        buildspec    = "buildspec.yml"
      }
      pull_build_name           = "automationdoc-codebuild-pull-code"
      pipeline_name             = "<project>-<application>-service-codepipeline-<environment>"
      allow_pull_cross_account  = false
      allow_pull_principle_arns = {}
      pull                      = false
      build                     = true
      deploy                    = true
      review                    = true
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
        pull = {}
      }
      tags = {
        Environment = "<environment>"
        Application = "<application>"
      }
    }]
    web_pipeline_configs = [{
      repo_name             = "<application>-web"
      source_provider       = "S3"
      source_s3_bucket_name = "automationdoc-ssm-<workload_id>"
      source_s3_object_key  = "<application>-web-<environment>/<application>-web-<environment>.zip"
      bucket_name           = "<application>-web-<environment>"
      ci_build_name         = "<project>-<application>-web-ci-codebuild-<environment>"
      review_build_name     = "<project>-<application>-web-review-codebuild-<environment>"
      codebuild_image_config = {
        compute_type = "BUILD_GENERAL1_SMALL"
        image        = "aws/codebuild/standard:7.0"
        type         = "LINUX_CONTAINER"
        buildspec    = "buildspec.yml"
      }
      pull_build_name           = "automationdoc-codebuild-pull-code"
      pipeline_name             = "<project>-<application>-web-codepipeline-<environment>"
      allow_pull_cross_account  = false
      allow_pull_principle_arns = {}
      pull                      = false
      build                     = true
      deploy                    = false
      review                    = true
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
        pull = {}
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
