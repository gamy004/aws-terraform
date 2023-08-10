locals {
  ci_configs = {
    for config in lookup(var.configs, "service_configs", []) : config.service_name => {
      pipeline_build_name = "${config.pipeline_build_name}"
    }
  }

  current_account_id = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "ci" {
  for_each    = local.ci_configs
  description = "Policy used in trust relationship with CodeBuild"
  name        = "CodeBuildBasePolicy-${each.value.pipeline_build_name}"
  path        = "/service-role/"
  policy = jsonencode(
    {
      Statement = [
        {
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
          ]
          Effect = "Allow"
          Resource = [
            "arn:aws:logs:${var.region}:${local.current_account_id}:log-group:/aws/codebuild/${each.value.pipeline_build_name}",
            "arn:aws:logs:${var.region}:${local.current_account_id}:log-group:/aws/codebuild/${each.value.pipeline_build_name}:*",
          ]
        },
        {
          Action = [
            "s3:PutObject",
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:GetBucketAcl",
            "s3:GetBucketLocation",
          ]
          Effect = "Allow"
          Resource = [
            "arn:aws:s3:::codepipeline-${var.region}-*",
          ]
        },
        {
          Action = [
            "codebuild:CreateReportGroup",
            "codebuild:CreateReport",
            "codebuild:UpdateReport",
            "codebuild:BatchPutTestCases",
            "codebuild:BatchPutCodeCoverages",
          ]
          Effect = "Allow"
          Resource = [
            "arn:aws:codebuild:${var.region}:${local.current_account_id}:report-group/${each.value.pipeline_build_name}-*",
          ]
        },
      ]
      Version = "2012-10-17"
    }
  )
  tags = merge(var.tags, { Name : "CodeBuildBasePolicy-${each.value.pipeline_build_name}" })
}

resource "aws_iam_role" "ci" {
  for_each = local.ci_configs
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "codebuild.amazonaws.com"
          }
        },
      ]
      Version = "2012-10-17"
    }
  )
  force_detach_policies = false
  managed_policy_arns = [
    var.configs.parameter_store_access_policy_arn,
    var.configs.s3_access_policy_arn,
    aws_iam_policy.ci[each.key].arn
  ]
  max_session_duration = 3600
  name                 = "${each.value.pipeline_build_name}-service-role"
  path                 = "/"
  inline_policy {
    name = "allow-assume-role-cloudfront-invalidate-policy"
    policy = jsonencode(
      {
        Statement = [
          {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            # Resource = "arn:aws:iam::994756134565:role/kmutt-cloudfront-invalidation-nonprod-role"
            Resource = var.configs.cloudfront_invalidation_role_arn
          },
        ]
        Version = "2012-10-17"
      }
    )
  }
  inline_policy {
    name = "${each.value.pipeline_build_name}-ecs-codebuild-policy"
    policy = jsonencode(
      {
        Statement = [
          {
            Action = [
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents",
              "ecr:GetAuthorizationToken",
            ]
            Effect   = "Allow"
            Resource = "*"
          },
          {
            Action = [
              "s3:GetObject",
              "s3:PutObject",
              "s3:GetObjectVersion",
            ]
            Effect   = "Allow"
            Resource = "*"
          },
          {
            Action = [
              "ecr:GetDownloadUrlForLayer",
              "ecr:BatchGetImage",
              "ecr:BatchCheckLayerAvailability",
              "ecr:PutImage",
              "ecr:InitiateLayerUpload",
              "ecr:UploadLayerPart",
              "ecr:CompleteLayerUpload",
            ]
            Effect   = "Allow"
            Resource = "*"
          },
        ]
        Version = "2012-10-17"
      }
    )
  }
  tags = merge(var.tags, { Name : "${each.value.pipeline_build_name}-service-role" })
}

# resource "aws_codebuild_project" "ci" {
#   for_each = 
#   badge_enabled      = false
#   build_timeout      = 10
#   encryption_key     = "arn:aws:kms:${var.region}:${local.current_account_id}:alias/aws/s3"
#   name               = "${var.project_name}-${var.service_name}-ci-codebuild-${var.env}"
#   project_visibility = "PRIVATE"
#   queued_timeout     = 480
#   service_role       = aws_iam_role.ci[0].arn
#   tags               = local.tags

#   artifacts {
#     encryption_disabled    = false
#     name                   = "${var.project_name}-${var.service_name}-ci-codebuild-${var.env}"
#     override_artifact_name = false
#     packaging              = "NONE"
#     type                   = "CODEPIPELINE"
#   }

#   cache {
#     modes = []
#     type  = "NO_CACHE"
#   }

#   environment {
#     compute_type                = "BUILD_GENERAL1_SMALL"
#     image                       = "aws/codebuild/standard:5.0"
#     image_pull_credentials_type = "CODEBUILD"
#     privileged_mode             = true
#     type                        = "LINUX_CONTAINER"

#     environment_variable {
#       name  = "AWS_DEFAULT_REGION"
#       type  = "PLAINTEXT"
#       value = "${var.region}"
#     }
#     environment_variable {
#       name  = "DOCKER_PASSWORD"
#       type  = "PLAINTEXT"
#       value = "kmuttdk832"
#     }
#   }

#   source {
#     buildspec           = "buildspec.yml"
#     git_clone_depth     = 0
#     insecure_ssl        = false
#     report_build_status = false
#     type                = "CODEPIPELINE"
#   }
# }
