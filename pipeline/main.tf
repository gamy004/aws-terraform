locals {
  ci_configs = {
    for config in lookup(var.configs, "service_configs", []) : config.service_name => {
      name = "${config.ci_build_name}"
      environment_variables = merge(
        {
          for variable_name, variable_config in lookup(config.environment_variables, "build", {}) : variable_name => variable_config
        },
        {
          #           CF_ROLE_ARN = {
          #             type  = "PLAINTEXT"
          # value = "${var.configs.cloudfront_invalidation_role_arn}"
          #           }
          #           DISTRIBUTION_ID = {
          #             type  = "PLAINTEXT"
          # value = "${var.configs.cloudfront_dist_id}"
          #           }
          # S3_BUCKET = {
          #   type  = "PLAINTEXT"
          #   value = "${aws_s3_bucket.pipeline[config.service_name].id}"
          # }
          REPOSITORY_URL = {
            type  = "PLAINTEXT"
            value = "${aws_ecr_repository.pipeline[config.service_name].repository_url}"
          }
          PROJECT = {
            type  = "PLAINTEXT"
            value = config.service_name
          }
          ENV = {
            type  = "PLAINTEXT"
            value = var.tags.Stage
          }
        }
      )

    }
  }

  review_configs = {
    for config in lookup(var.configs, "service_configs", []) : config.service_name => {
      name = "${config.review_build_name}"
      environment_variables = merge(
        {
          for variable_name, variable_config in lookup(config.environment_variables, "review", {}) : variable_name => variable_config
        },
        {
          PROJECT = {
            type  = "PLAINTEXT"
            value = config.service_name
          }
          ENV = {
            type  = "PLAINTEXT"
            value = var.tags.Stage
          }
        }
      )

    }
  }

  pipeline_configs = {
    for config in lookup(var.configs, "service_configs", []) : config.service_name => {
      name        = "${config.pipeline_name}"
      repo_name   = "${config.repo_name}"
      repo_id     = var.configs.repo_configs[config.repo_name].id
      repo_branch = var.configs.repo_configs[config.repo_name].env_branch_mapping[config.tags.Environment]
    }
  }

  current_account_id = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}

data "aws_kms_alias" "s3" {
  name = "alias/aws/s3"
}

resource "aws_s3_bucket" "artifact" {
  bucket = var.configs.s3_artifact_bucket_name

  tags = merge(var.tags, { Name : "${var.configs.s3_artifact_bucket_name}" })
}

resource "aws_ecr_repository" "pipeline" {
  for_each             = local.pipeline_configs
  name                 = each.key
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, { Name : "${each.key}" })
}
# resource "aws_s3_bucket" "pipeline" {
#   for_each = local.pipeline_configs

#   bucket = "${each.key}-${local.current_account_id}"

#   tags = merge(var.tags, { Name : "${each.key}-${local.current_account_id}" })
# }

resource "aws_iam_policy" "ci" {
  for_each    = local.ci_configs
  description = "Policy used in trust relationship with CodeBuild"
  name        = "CodeBuildBasePolicy-${each.value.name}"
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
            "arn:aws:logs:${var.region}:${local.current_account_id}:log-group:/aws/codebuild/${each.value.name}",
            "arn:aws:logs:${var.region}:${local.current_account_id}:log-group:/aws/codebuild/${each.value.name}:*",
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
            "arn:aws:codebuild:${var.region}:${local.current_account_id}:report-group/${each.value.name}-*",
          ]
        },
      ]
      Version = "2012-10-17"
    }
  )
  tags = merge(var.tags, { Name : "CodeBuildBasePolicy-${each.value.name}" })
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
  name                 = "${each.value.name}-service-role"
  path                 = "/"
  inline_policy {
    name = "allow-assume-role-cloudfront-invalidate-policy"
    policy = jsonencode(
      {
        Statement = [
          {
            Action   = "sts:AssumeRole"
            Effect   = "Allow"
            Resource = var.configs.cloudfront_invalidation_role_arn
          },
        ]
        Version = "2012-10-17"
      }
    )
  }
  inline_policy {
    name = "${each.value.name}-ecs-codebuild-policy"
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
  tags = merge(var.tags, { Name : "${each.value.name}-service-role" })
}

resource "aws_iam_policy" "base_review" {
  for_each    = local.review_configs
  description = "Policy used in trust relationship with CodeBuildReview"
  name        = "CodeBuildBasePolicy-${each.value.name}"
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
            "arn:aws:logs:${var.region}:${local.current_account_id}:log-group:/aws/codebuild/${each.value.name}",
            "arn:aws:logs:${var.region}:${local.current_account_id}:log-group:/aws/codebuild/${each.value.name}:*",
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
            "arn:aws:codebuild:${var.region}:${local.current_account_id}:report-group/${each.value.name}-*",
          ]
        },
      ]
      Version = "2012-10-17"
    }
  )
  tags = merge(var.tags, { Name : "CodeBuildBasePolicy-${each.value.name}" })
}

resource "aws_iam_policy" "vpc_review" {
  for_each    = local.review_configs
  description = "Policy used in trust relationship with CodeBuildReview"
  name        = "CodeBuildVpcPolicy-${each.value.name}"
  path        = "/service-role/"
  policy = jsonencode(
    {
      Statement = [
        {
          Action = [
            "ec2:CreateNetworkInterface",
            "ec2:DescribeDhcpOptions",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DeleteNetworkInterface",
            "ec2:DescribeSubnets",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeVpcs",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "ec2:CreateNetworkInterfacePermission",
          ]
          Condition = {
            StringEquals = {
              "ec2:AuthorizedService" = "codebuild.amazonaws.com"
              "ec2:Subnet" = [
                for subnet_id in var.configs.review_subnet_ids : "arn:aws:ec2:${var.region}:${local.current_account_id}:subnet/${subnet_id}"
              ]
            }
          }
          Effect   = "Allow"
          Resource = "arn:aws:ec2:${var.region}:${local.current_account_id}:network-interface/*"
        },
      ]
      Version = "2012-10-17"
    }
  )
  tags = merge(var.tags, { Name : "CodeBuildVpcPolicy-${each.value.name}" })
}

resource "aws_iam_role" "review" {
  for_each = local.review_configs
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
    aws_iam_policy.base_review[each.key].arn,
    aws_iam_policy.vpc_review[each.key].arn
  ]
  max_session_duration = 3600
  name                 = "${each.value.name}-service-role"
  path                 = "/"
  tags                 = merge(var.tags, { Name : "${each.value.name}-service-role" })

  inline_policy {
    name = "${each.value.name}-codebuild-policy"
    policy = jsonencode(
      {
        Statement = [
          {
            Action = [
              "acm:ListCertificates",
              "apigateway:*",
              "cloudformation:*",
              "cloudwatch:*",
              "codebuild:*",
              "codecommit:GetBranch",
              "codecommit:GetCommit",
              "codecommit:GetRepository",
              "codecommit:GitPull",
              "codecommit:GitPush",
              "codecommit:ListBranches",
              "codecommit:ListRepositories",
              "codepipeline:*Execution",
              "codepipeline:Get*",
              "codepipeline:List*",
              "cognito-identity:*",
              "cognito-idp:*",
              "cognito-sync:*",
              "dynamodb:*",
              "ec2:*NetworkInterface*",
              "ec2:DescribeDhcpOptions",
              "ec2:DescribeSecurityGroups",
              "ec2:DescribeSubnets",
              "ec2:DescribeVpcs",
              "ecr:*",
              "eks:Describe*",
              "events:*",
              "execute-api:Invoke",
              "execute-api:ManageConnections",
              "iam:*",
              "iot:*",
              "kinesis:DescribeStream",
              "kinesis:ListStreams",
              "kinesis:PutRecord",
              "kms:ListAliases",
              "lambda:*",
              "logs:*",
              "mobiletargeting:GetApps",
              "s3:*",
              "ses:*",
              "sns:*",
              "sqs:ListQueues",
              "sqs:SendMessage",
              "ssm:*Parameter*",
              "ssm:AddTagsToResource",
              "ssm:RemoveTagsFromResource",
              "tag:GetResources",
              "xray:PutTelemetryRecords",
              "xray:PutTraceSegments",
            ]
            Effect   = "Allow"
            Resource = "*"
          },
        ]
        Version = "2012-10-17"
      }
    )
  }
}

resource "aws_iam_role" "pipeline" {
  for_each = local.pipeline_configs

  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "codepipeline.amazonaws.com"
          }
        },
      ]
      Version = "2012-10-17"
    }
  )
  force_detach_policies = false
  managed_policy_arns   = []
  max_session_duration  = 3600
  name                  = "${each.value.name}-service-role"
  path                  = "/"
  tags                  = merge(var.tags, { Name : "${each.value.name}-service-role" })

  inline_policy {
    name = "${each.value.name}-ecs-codepipeline-policy"
    policy = jsonencode(
      {
        Statement = [
          {
            Action = [
              "iam:PassRole",
            ]
            Condition = {
              StringEqualsIfExists = {
                "iam:PassedToService" = [
                  "cloudformation.amazonaws.com",
                  "elasticbeanstalk.amazonaws.com",
                  "ec2.amazonaws.com",
                  "ecs-tasks.amazonaws.com",
                ]
              }
            }
            Effect   = "Allow"
            Resource = "*"
          },
          {
            Action = [
              "codecommit:CancelUploadArchive",
              "codecommit:GetBranch",
              "codecommit:GetCommit",
              "codecommit:GetUploadArchiveStatus",
              "codecommit:UploadArchive",
            ]
            Effect   = "Allow"
            Resource = "*"
          },
          {
            Action = [
              "codedeploy:CreateDeployment",
              "codedeploy:GetApplication",
              "codedeploy:GetApplicationRevision",
              "codedeploy:GetDeployment",
              "codedeploy:GetDeploymentConfig",
              "codedeploy:RegisterApplicationRevision",
            ]
            Effect   = "Allow"
            Resource = "*"
          },
          {
            Action = [
              "elasticbeanstalk:*",
              "ec2:*",
              "elasticloadbalancing:*",
              "autoscaling:*",
              "cloudwatch:*",
              "s3:*",
              "sns:*",
              "cloudformation:*",
              "rds:*",
              "sqs:*",
              "ecs:*",
              "logs:*",
              "codestar:*",
              "codestar-connections:*",
            ]
            Effect   = "Allow"
            Resource = "*"
          },
          {
            Action = [
              "lambda:InvokeFunction",
              "lambda:ListFunctions",
            ]
            Effect   = "Allow"
            Resource = "*"
          },
          {
            Action = [
              "opsworks:CreateDeployment",
              "opsworks:DescribeApps",
              "opsworks:DescribeCommands",
              "opsworks:DescribeDeployments",
              "opsworks:DescribeInstances",
              "opsworks:DescribeStacks",
              "opsworks:UpdateApp",
              "opsworks:UpdateStack",
            ]
            Effect   = "Allow"
            Resource = "*"
          },
          {
            Action = [
              "cloudformation:CreateStack",
              "cloudformation:DeleteStack",
              "cloudformation:DescribeStacks",
              "cloudformation:UpdateStack",
              "cloudformation:CreateChangeSet",
              "cloudformation:DeleteChangeSet",
              "cloudformation:DescribeChangeSet",
              "cloudformation:ExecuteChangeSet",
              "cloudformation:SetStackPolicy",
              "cloudformation:ValidateTemplate",
            ]
            Effect   = "Allow"
            Resource = "*"
          },
          {
            Action = [
              "codebuild:BatchGetBuilds",
              "codebuild:StartBuild",
            ]
            Effect   = "Allow"
            Resource = "*"
          },
          {
            Action = [
              "devicefarm:ListProjects",
              "devicefarm:ListDevicePools",
              "devicefarm:GetRun",
              "devicefarm:GetUpload",
              "devicefarm:CreateUpload",
              "devicefarm:ScheduleRun",
            ]
            Effect   = "Allow"
            Resource = "*"
          },
          {
            Action = [
              "servicecatalog:ListProvisioningArtifacts",
              "servicecatalog:CreateProvisioningArtifact",
              "servicecatalog:DescribeProvisioningArtifact",
              "servicecatalog:DeleteProvisioningArtifact",
              "servicecatalog:UpdateProduct",
            ]
            Effect   = "Allow"
            Resource = "*"
          },
          {
            Action = [
              "cloudformation:ValidateTemplate",
            ]
            Effect   = "Allow"
            Resource = "*"
          },
          {
            Action = [
              "ecr:DescribeImages",
            ]
            Effect   = "Allow"
            Resource = "*"
          },
        ]
        Version = "2012-10-17"
      }
    )
  }
}

resource "aws_codebuild_project" "ci" {
  for_each           = local.ci_configs
  badge_enabled      = false
  build_timeout      = 10
  encryption_key     = data.aws_kms_alias.s3.arn
  name               = each.value.name
  project_visibility = "PRIVATE"
  queued_timeout     = 480
  service_role       = aws_iam_role.ci[each.key].arn
  tags               = merge(var.tags, { Name : "${each.value.name}" })

  artifacts {
    encryption_disabled    = false
    name                   = each.value.name
    override_artifact_name = false
    packaging              = "NONE"
    type                   = "CODEPIPELINE"
  }

  cache {
    modes = []
    type  = "NO_CACHE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true
    type                        = "LINUX_CONTAINER"

    dynamic "environment_variable" {
      for_each = each.value.environment_variables

      content {
        name  = environment_variable.key
        type  = environment_variable.value.type
        value = environment_variable.value.value
      }
    }
  }

  source {
    buildspec           = "buildspec.yml"
    git_clone_depth     = 0
    insecure_ssl        = false
    report_build_status = false
    type                = "CODEPIPELINE"
  }
}

resource "aws_codebuild_project" "review" {
  for_each           = local.review_configs
  badge_enabled      = false
  build_timeout      = 60
  encryption_key     = data.aws_kms_alias.s3.arn
  name               = each.value.name
  project_visibility = "PRIVATE"
  queued_timeout     = 480
  service_role       = aws_iam_role.review[each.key].arn
  tags               = merge(var.tags, { Name = "${each.value.name}" })

  artifacts {
    encryption_disabled    = false
    name                   = each.value.name
    override_artifact_name = false
    packaging              = "NONE"
    type                   = "CODEPIPELINE"
  }

  cache {
    modes = []
    type  = "NO_CACHE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true
    type                        = "LINUX_CONTAINER"

    dynamic "environment_variable" {
      for_each = each.value.environment_variables

      content {
        name  = environment_variable.key
        type  = environment_variable.value.type
        value = environment_variable.value.value
      }
    }
  }

  source {
    buildspec           = "review.buildspec.yml"
    git_clone_depth     = 0
    insecure_ssl        = false
    report_build_status = false
    type                = "CODEPIPELINE"
  }

  vpc_config {
    security_group_ids = var.configs.review_security_group_ids
    subnets            = var.configs.review_subnet_ids
    vpc_id             = var.vpc_id
  }
}

resource "aws_codestarconnections_connection" "repo" {
  for_each = var.configs.repo_configs

  name          = each.key
  provider_type = each.value.provider
}

resource "aws_codepipeline" "pipeline" {
  for_each = local.pipeline_configs
  name     = each.value.name
  role_arn = aws_iam_role.pipeline[each.key].arn
  tags     = merge(var.tags, { Name : "${each.value.name}" })

  artifact_store {
    location = aws_s3_bucket.artifact.id
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      category = "Source"
      configuration = {
        "BranchName"       = each.value.repo_branch
        "ConnectionArn"    = aws_codestarconnections_connection.repo[each.value.repo_name].arn
        "FullRepositoryId" = each.value.repo_id
      }
      input_artifacts = []
      name            = "Source"
      output_artifacts = [
        "${each.value.name}-src",
      ]
      owner     = "AWS"
      provider  = "CodeStarSourceConnection"
      run_order = 1
      version   = "1"
    }
  }
  stage {
    name = "Build"

    action {
      category = "Build"
      configuration = {
        "ProjectName" = aws_codebuild_project.ci[each.key].name
      }
      input_artifacts = [
        "${each.value.name}-src",
      ]
      name = "Build"
      output_artifacts = [
        "${each.value.name}-build",
      ]
      owner     = "AWS"
      provider  = "CodeBuild"
      region    = var.region
      run_order = 1
      version   = "1"
    }
  }
  stage {
    name = "Deploy-and-Review"

    action {
      category = "Deploy"
      configuration = {
        "ClusterName" = var.configs.cluster_name
        "FileName"    = "imagedefinitions.json"
        "ServiceName" = each.key
      }
      input_artifacts = [
        "${each.value.name}-build",
      ]
      name             = "Deploy"
      output_artifacts = []
      owner            = "AWS"
      provider         = "ECS"
      run_order        = 1
      version          = "1"
    }
    action {
      category = "Build"
      configuration = {
        "ProjectName" = aws_codebuild_project.review[each.key].name
      }
      input_artifacts = [
        "${each.value.name}-src",
      ]
      name             = "Review"
      output_artifacts = []
      owner            = "AWS"
      provider         = "CodeBuild"
      run_order        = 1
      version          = "1"
    }
  }
}
