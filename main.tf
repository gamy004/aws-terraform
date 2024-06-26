locals {
  tags = {
    Project   = var.project_name
    Stage     = var.stage
    Terraform = true
  }

  has_pipeline_review_stage = contains(keys(var.build_configs.pipeline_stages), "review")

  api_configs = flatten([
    for application in var.applications : [
      for environment in var.environments : {
        service_name      = try(var.backend_configs["${application}-${environment}"].service_name, "${application}-service-${environment}")
        host_header_name  = "${try(var.backend_configs["${application}-${environment}"].sub_domain_name, "${environment}-api-${application}")}.${var.domain_name}"
        api_gateway_name  = "${application}-api-gw-${environment}"
        target_group_name = "${application}-ecs-tg-${environment}"
        # module.s3_web[each.value.bucket_name].s3_bucket_bucket_regional_domain_name
        allowed_origins = [for allowed_origin in try(var.backend_configs["${application}-${environment}"].allowed_origins, []) : "'${allowed_origin}'"]
        tags = {
          Environment = environment
          Application = application
        }
      }
    ]
  ])

  web_configs = flatten([
    for application in var.applications : [
      for environment in var.environments : {
        certificate_arn  = var.frontend_configs["${application}-${environment}"].cloudfront_certificate_arn
        host_header_name = "${try(var.frontend_configs["${application}-${environment}"].sub_domain_name, "${environment}-${application}")}.${var.domain_name}"
        cloudfront_name  = "${application}-web-cf-${environment}"
        bucket_name      = try(var.frontend_configs["${application}-${environment}"].bucket_name, "${application}-web-${environment}") # must match with `bucket_name` in pipeline
        tags = {
          Environment = environment
          Application = application
        }
      }
    ]
  ])

  default_environment_variables = {
    AWS_DEFAULT_REGION = {
      type  = "PLAINTEXT"
      value = "${var.aws_region}"
    }
  }

  # ref avaialble compute types: https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-compute-types.html
  # ref avaialble runtimes: https://docs.aws.amazon.com/codebuild/latest/userguide/available-runtimes.html
  default_codebuild_image_config = {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"
    buildspec    = "buildspec.yml"
  }

  service_ecs_configs = flatten([
    for application in var.applications : [
      for environment in var.environments : merge(
        lookup(var.backend_configs, "${application}-${environment}", {}),
        {
          service_name   = try(var.backend_configs["${application}-${environment}"].service_name, "${application}-service-${environment}") # must match with `service_name` in pipeline
          container_name = try(var.backend_configs["${application}-${environment}"].container_name, "${application}-service")
          environment_variables = merge(
            local.default_environment_variables,
            try(var.backend_configs["${application}-${environment}"].environment_variables, {}),
          )
          tags = {
            Environment = environment
            Application = application
          }
        }
      )
    ]
  ])

  service_pipeline_configs = flatten([
    for application in var.applications : [
      for environment in var.environments : merge(
        lookup(var.backend_configs, "${application}-${environment}", {}),
        {
          repo_name                 = try(var.backend_configs["${application}-${environment}"].repo_name, "${application}-service")
          source_provider           = try(var.build_configs.pipeline_stages.source["${application}-service-${environment}"].provider, "CodeStarSourceConnection")
          source_s3_bucket_name     = try(var.build_configs.pipeline_stages.source["${application}-service-${environment}"].s3_bucket_name, "")
          source_s3_object_key      = try(var.build_configs.pipeline_stages.source["${application}-service-${environment}"].s3_object_key, "")        // ${each.value.name}/${each.value.name}.zip
          service_name              = try(var.backend_configs["${application}-${environment}"].service_name, "${application}-service-${environment}") # must match with `service_name` in ecs
          ci_build_name             = "${application}-service-ci-codebuild-${environment}"
          review_build_name         = "${application}-service-review-codebuild-${environment}"
          codebuild_image_config    = try(var.build_configs.codebuild_image_configs["${application}-service-${environment}"], local.default_codebuild_image_config)
          pull_build_name           = try(var.build_configs.pipeline_stages.pull["${application}-service-${environment}"].codebuild_name, "automationdoc-codebuild-pull-image")
          pipeline_name             = "${application}-service-codepipeline-${environment}"
          pull                      = lookup(try(var.build_configs.pipeline_stages.pull, {}), "${application}-service-${environment}", false) != false
          allow_pull_cross_account  = try(var.build_configs.ecr_configs["${application}-service-${environment}"].allow_pull_cross_account, false) != false
          allow_pull_principle_arns = try(var.build_configs.ecr_configs["${application}-service-${environment}"].allow_pull_principle_arns, {})
          build                     = try(var.build_configs.pipeline_stages.build["${application}-service-${environment}"], true)
          deploy                    = try(var.build_configs.pipeline_stages.deploy["${application}-service-${environment}"], true)
          review                    = try(var.build_configs.pipeline_stages.review["${application}-service-${environment}"], false)
          environment_variables = {
            build = merge(
              local.default_environment_variables,
              # lookup(try(var.build_configs.environment_variables, {}), "all", {}),
              lookup(try(var.build_configs.environment_variables.build, {}), "all", {}),
              lookup(try(var.build_configs.environment_variables.build, {}), "${application}-service", {}),
              lookup(try(var.build_configs.environment_variables.build, {}), "${application}-service-${environment}", {}),
              {
                CF_ROLE_ARN = {
                  type  = "PLAINTEXT"
                  value = "${data.aws_iam_role.cloudfront_invalidation_role.arn}"
                }
                DISTRIBUTION_ID = {
                  type  = "PLAINTEXT"
                  value = "${module.api_cdn.cloudfront.cloudfront_distribution_id}"
                }
              }
            )
            review = merge(
              local.default_environment_variables,
              # lookup(try(var.build_configs.environment_variables, {}), "all", {}),
              lookup(try(var.build_configs.environment_variables.review, {}), "all", {}),
              lookup(try(var.build_configs.environment_variables.review, {}), "${application}-service", {}),
              lookup(try(var.build_configs.environment_variables.review, {}), "${application}-service-${environment}", {}),
            )
            pull = merge(
              local.default_environment_variables,
              # lookup(try(var.build_configs.environment_variables, {}), "all", {}),
              lookup(try(var.build_configs.environment_variables.pull, {}), "all", {}),
              lookup(try(var.build_configs.environment_variables.pull, {}), "${application}-service", {}),
              lookup(try(var.build_configs.environment_variables.pull, {}), "${application}-service-${environment}", {}),
            )
          }
          tags = {
            Environment = environment
            Application = application
          }
        }
      )
    ]
  ])

  web_pipeline_configs = flatten([
    for application in var.applications : [
      for environment in var.environments : merge(
        lookup(var.frontend_configs, "${application}-${environment}", {}),
        {
          repo_name                 = try(var.frontend_configs["${application}-${environment}"].repo_name, "${application}-web")
          source_provider           = try(var.build_configs.pipeline_stages.source["${application}-web-${environment}"].provider, "CodeStarSourceConnection")
          source_s3_bucket_name     = try(var.build_configs.pipeline_stages.source["${application}-web-${environment}"].s3_bucket_name, "")
          source_s3_object_key      = try(var.build_configs.pipeline_stages.source["${application}-web-${environment}"].s3_object_key, "")        // ${each.value.name}/${each.value.name}.zip
          bucket_name               = try(var.frontend_configs["${application}-${environment}"].bucket_name, "${application}-web-${environment}") # must match with `bucket_name` in web_configs
          ci_build_name             = "${application}-web-ci-codebuild-${environment}"
          review_build_name         = "${application}-web-review-codebuild-${environment}"
          codebuild_image_config    = try(var.build_configs.codebuild_image_configs["${application}-web-${environment}"], local.default_codebuild_image_config)
          pull_build_name           = try(var.build_configs.pipeline_stages.pull["${application}-web-${environment}"].codebuild_name, "automationdoc-codebuild-pull-code")
          pipeline_name             = "${application}-web-codepipeline-${environment}"
          pull                      = lookup(try(var.build_configs.pipeline_stages.pull, {}), "${application}-web-${environment}", false) != false
          allow_pull_cross_account  = try(var.build_configs.ecr_configs["${application}-web-${environment}"].allow_pull_cross_account, false) != false
          allow_pull_principle_arns = try(var.build_configs.ecr_configs["${application}-web-${environment}"].allow_pull_principle_arns, {})
          build                     = try(var.build_configs.pipeline_stages.build["${application}-web-${environment}"], true)
          deploy                    = try(var.build_configs.pipeline_stages.deploy["${application}-web-${environment}"], false)
          review                    = try(var.build_configs.pipeline_stages.review["${application}-web-${environment}"], false)
          environment_variables = {
            build = merge(
              local.default_environment_variables,
              # lookup(var.build_configs.environment_variables, "all", {}),
              lookup(var.build_configs.environment_variables.build, "all", {}),
              lookup(var.build_configs.environment_variables.build, "${application}-web", {}),
              lookup(var.build_configs.environment_variables.build, "${application}-web-${environment}", {}),
              {
                CF_ROLE_ARN = {
                  type  = "PLAINTEXT"
                  value = "${data.aws_iam_role.cloudfront_invalidation_role.arn}"
                }
                DISTRIBUTION_ID = {
                  type  = "PLAINTEXT"
                  value = "${module.web_cdn[try(var.frontend_configs["${application}-${environment}"].bucket_name, "${application}-web-${environment}")].cloudfront.cloudfront_distribution_id}"
                }
                S3_BUCKET = {
                  type  = "PLAINTEXT"
                  value = "${module.s3_web[try(var.frontend_configs["${application}-${environment}"].bucket_name, "${application}-web-${environment}")].s3_bucket_id}"
                }
              }
            )
            review = merge(
              local.default_environment_variables,
              # lookup(var.build_configs.environment_variables, "all", {}),
              lookup(var.build_configs.environment_variables.review, "all", {}),
              lookup(var.build_configs.environment_variables.review, "${application}-web", {}),
              lookup(var.build_configs.environment_variables.review, "${application}-web-${environment}", {}),
            )
            pull = merge(
              local.default_environment_variables,
              # lookup(var.build_configs.environment_variables, "all", {}),
              lookup(var.build_configs.environment_variables.pull, "all", {}),
              lookup(var.build_configs.environment_variables.pull, "${application}-web", {}),
              lookup(var.build_configs.environment_variables.pull, "${application}-web-${environment}", {}),
            )
          }
          tags = {
            Environment = environment
            Application = application
          }
        }
      )
    ]
  ])

  authentication_configs = {
    for environment in var.environments : environment => {
      user_pool_name = "${var.project_name}-user-pool-${environment}"
      lambda_configs = try(var.authentication_configs["${environment}"].lambda_configs, {})
      clients = {
        for client_name, client_config in try(var.authentication_configs["${environment}"].client_configs, {}) : "${client_name}-${environment}" => {
          generate_secret        = try(client_config.generate_secret, false)
          access_token_validity  = try(client_config.access_token_validity.duration, 24)
          id_token_validity      = try(client_config.id_token_validity.duration, 24)
          refresh_token_validity = try(client_config.refresh_token_validity.duration, 90)
          token_validity_units = {
            access_token  = try(client_config.access_token_validity.unit, "hours")
            id_token      = try(client_config.id_token_validity.unit, "hours")
            refresh_token = try(client_config.refresh_token_validity.unit, "days")
          }
          explicit_auth_flows = try(client_config.explicit_auth_flows, [
            "ALLOW_REFRESH_TOKEN_AUTH",
            "ALLOW_USER_PASSWORD_AUTH",
            "ALLOW_USER_SRP_AUTH"
          ])
        }
      }
      tags = {
        Environment = environment
      }
    }
  }

  parameter_store_configs = flatten([
    for application in var.applications : [
      for environment in var.environments : {
        prefix     = "${application}/${environment}"
        parameters = try(var.parameter_store_configs.parameters["${application}-${environment}"], {})
        tags = {
          Environment = environment
          Application = application
        }
      }
    ]
  ])
}

provider "aws" {
  alias = "workload_database_role"
  assume_role {
    role_arn = "arn:aws:iam::${var.workload_account_id}:role/KMUTTDatabaseRole"
  }
}

provider "aws" {
  alias = "workload_infra_role"
  assume_role {
    role_arn = "arn:aws:iam::${var.workload_account_id}:role/KMUTTInfraRole"
  }
}

provider "aws" {
  alias = "workload_security_role"
  assume_role {
    role_arn = "arn:aws:iam::${var.workload_account_id}:role/KMUTTSecurityRole"
  }
}

provider "aws" {
  alias = "network_infra_role"
  assume_role {
    role_arn = "arn:aws:iam::${var.network_account_id}:role/KMUTTInfraRole"
  }
}

provider "aws" {
  alias  = "network_infra_role_for_cloudfront"
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::${var.network_account_id}:role/KMUTTInfraRole"
  }
}

data "aws_iam_account_alias" "workload_account_alias" {
  provider = aws.workload_infra_role
}

data "aws_iam_account_alias" "network_account_alias" {
  provider = aws.network_infra_role
}

data "aws_vpc" "workload_vpc" {
  provider = aws.workload_infra_role
  filter {
    name   = "tag:Name"
    values = ["${data.aws_iam_account_alias.workload_account_alias.account_alias}-vpc"]
  }
}

data "aws_vpc" "network_vpc" {
  provider = aws.network_infra_role
  filter {
    name   = "tag:Name"
    values = ["${data.aws_iam_account_alias.network_account_alias.account_alias}-inbound-vpc"]
  }
}

data "aws_acm_certificate" "workload_certificate" {
  provider    = aws.workload_infra_role
  domain      = var.domain_name
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

data "aws_acm_certificate" "network_certificate" {
  provider    = aws.network_infra_role
  domain      = var.domain_name
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

data "aws_iam_role" "api_gateway_cloudwatch_role" {
  provider = aws.workload_infra_role

  name = "kmutt-api-gateway-logs-role-${var.stage}"
}

data "aws_iam_role" "database_monitoring_role" {
  provider = aws.workload_infra_role

  name = "rds-monitoring-role"
}

data "aws_iam_role" "cloudfront_invalidation_role" {
  provider = aws.network_infra_role

  name = "kmutt-cloudfront-invalidation-${var.stage}-role"
}

data "aws_iam_policy" "parameter_store_access" {
  provider = aws.workload_infra_role

  name = "kmutt-access-parameters-policy"
}

data "aws_iam_policy" "s3_access" {
  provider = aws.workload_infra_role

  name = "kmutt-access-s3-policy"
}

data "aws_subnets" "external_subnets" {
  provider = aws.network_infra_role
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.network_vpc.id]
  }

  filter {
    name   = "tag:Name"
    values = ["${data.aws_iam_account_alias.network_account_alias.account_alias}-inbound-untrust*"]
  }
}

data "aws_subnets" "private_subnets" {
  provider = aws.workload_infra_role
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.workload_vpc.id]
  }

  filter {
    name   = "tag:Name"
    values = ["${data.aws_iam_account_alias.workload_account_alias.account_alias}-nonexpose*"]
  }
}

data "aws_subnets" "public_subnets" {
  provider = aws.workload_infra_role
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.workload_vpc.id]
  }


  filter {
    name   = "tag:Name"
    values = ["${data.aws_iam_account_alias.workload_account_alias.account_alias}-app*"]
  }
}

data "aws_subnet" "review" {
  count = local.has_pipeline_review_stage ? 1 : 0

  provider = aws.workload_infra_role
  filter {
    name   = "tag:Name"
    values = ["${data.aws_iam_account_alias.workload_account_alias.account_alias}-app-b"]
  }
}

data "aws_security_group" "review" {
  count = local.has_pipeline_review_stage ? 1 : 0

  provider = aws.workload_infra_role
  filter {
    name   = "tag:Name"
    values = ["kmutt-codebuild-sg-${var.stage}"]
  }
}

data "aws_db_subnet_group" "database" {
  provider = aws.workload_database_role
  name     = var.db_configs.subnet_group_name
}

data "aws_vpc_endpoint" "api_gateway_endpoint" {
  provider     = aws.workload_infra_role
  vpc_id       = data.aws_vpc.workload_vpc.id
  service_name = "com.amazonaws.${var.aws_region}.execute-api"
}

module "security_groups" {
  source = "./seceruity-group"

  providers = {
    aws.workload = aws.workload_security_role
    aws.network  = aws.network_infra_role
  }

  workload_vpc_id = data.aws_vpc.workload_vpc.id
  network_vpc_id  = data.aws_vpc.network_vpc.id
  configs = merge(
    var.sg_configs,
    {
      secure_security_group_name       = "${var.project_name}-secure-sg-${var.stage}"
      app_security_group_name          = "${var.project_name}-app-sg-${var.stage}"
      external_alb_security_group_name = "${var.project_name}-external-alb-sg-${var.stage}"
      public_alb_security_group_name   = "${var.project_name}-alb-sg-${var.stage}"
      private_alb_security_group_name  = "${var.project_name}-nonexpose-alb-sg-${var.stage}"
      db_ports                         = [3306, 5432]
    }
  )
  tags = local.tags
}

# Internal Load Balancer
module "internal_lb" {
  source = "./internal-load-balancer"

  providers = {
    aws = aws.workload_infra_role
  }

  vpc_id          = data.aws_vpc.workload_vpc.id
  certificate_arn = data.aws_acm_certificate.workload_certificate.arn
  configs = {
    public_alb_name                = "${var.project_name}-alb-${var.stage}"
    private_alb_name               = "${var.project_name}-internal-alb-${var.stage}"
    private_nlb_name               = "${var.project_name}-internal-nlb-${var.stage}"
    public_alb_target_group_name   = "${var.project_name}-api-gw-tg-${var.stage}"
    private_nlb_target_group_name  = "${var.project_name}-internal-nlb-tg-${var.stage}"
    public_alb_security_group_ids  = [module.security_groups.public_alb_sg.id]
    private_alb_security_group_ids = [module.security_groups.private_alb_sg.id]
    public_alb_subnet_ids          = data.aws_subnets.public_subnets.ids
    private_alb_subnet_ids         = data.aws_subnets.private_subnets.ids
    private_nlb_subnet_ids         = data.aws_subnets.private_subnets.ids
    api_gateway_vpc_endpoint_ids   = [data.aws_vpc_endpoint.api_gateway_endpoint.id]
    api_configs                    = local.api_configs
  }
  tags = local.tags
}

## External Load Balancer
module "external_lb" {
  source = "./external-load-balancer"

  providers = {
    aws = aws.network_infra_role
  }

  region          = var.aws_region
  vpc_id          = data.aws_vpc.network_vpc.id
  certificate_arn = data.aws_acm_certificate.network_certificate.arn
  configs = {
    name                         = "${var.project_name}-external-alb-${var.stage}"
    target_group_name            = "${var.project_name}-external-alb-tg-${var.stage}"
    security_group_ids           = [module.security_groups.external_alb_sg.id]
    subnet_ids                   = data.aws_subnets.external_subnets.ids
    internal_public_alb_dns_name = module.internal_lb.public_alb.lb_dns_name
  }
  tags = local.tags
}

## API Gateway
module "api_gateway" {
  source = "./api-gateway"

  providers = {
    aws = aws.workload_infra_role
  }

  region              = var.aws_region
  vpc_id              = data.aws_vpc.workload_vpc.id
  domain_name         = var.domain_name
  cloudwatch_role_arn = data.aws_iam_role.api_gateway_cloudwatch_role.arn
  certificate_arn     = data.aws_acm_certificate.workload_certificate.arn
  configs = {
    name                         = "${var.project_name}-api-gw-${var.stage}"
    vpc_link_name                = "${var.project_name}-vpclink-${var.stage}"
    vpc_endpoint_ids             = [data.aws_vpc_endpoint.api_gateway_endpoint.id]
    private_nlb_target_group_arn = module.internal_lb.private_nlb.lb_arn
    private_nlb_dns_name         = module.internal_lb.private_nlb.lb_dns_name
    api_configs                  = local.api_configs
  }
  tags = local.tags
}

## Database
module "database" {
  source = "./database"

  providers = {
    aws = aws.workload_database_role
  }

  region              = var.aws_region
  vpc_id              = data.aws_vpc.workload_vpc.id
  subnet_group_name   = var.db_configs.subnet_group_name
  security_group_ids  = [module.security_groups.secure_sg.id]
  monitoring_role_arn = data.aws_iam_role.database_monitoring_role.arn
  configs             = var.db_configs.instances
  tags                = local.tags
}

## PARAMETER STORE
module "parameter_store" {
  providers = {
    aws = aws.workload_infra_role
  }

  source = "./parameter-store"

  region     = var.aws_region
  kms_key_id = var.parameter_store_configs.kms_key_id
  configs    = local.parameter_store_configs
  tags       = local.tags
}

## ECS
module "service" {
  source = "./service"

  providers = {
    aws = aws.workload_infra_role
  }

  region = var.aws_region
  vpc_id = data.aws_vpc.workload_vpc.id
  configs = {
    cluster_name                      = "${var.project_name}-cluster-${var.stage}"
    subnet_ids                        = data.aws_subnets.private_subnets.ids
    security_group_ids                = [module.security_groups.app_sg.id]
    target_group_arns                 = module.internal_lb.private_alb.target_group_arns
    parameter_store_access_policy_arn = data.aws_iam_policy.parameter_store_access.arn
    s3_access_policy_arn              = data.aws_iam_policy.s3_access.arn
    service_configs                   = local.service_ecs_configs
  }
  tags = local.tags
}

## CODE PIPELINE
module "pipeline" {
  source = "./pipeline"

  providers = {
    aws = aws.workload_infra_role
  }

  region = var.aws_region
  vpc_id = data.aws_vpc.workload_vpc.id
  configs = {
    cluster_name                      = "${var.project_name}-cluster-${var.stage}"
    parameter_store_access_policy_arn = data.aws_iam_policy.parameter_store_access.arn
    s3_access_policy_arn              = data.aws_iam_policy.s3_access.arn
    cloudfront_invalidation_role_arn  = data.aws_iam_role.cloudfront_invalidation_role.arn
    s3_artifact_bucket_name           = "${var.project_name}-artifacts-${var.workload_account_id}"
    review_subnet_ids                 = local.has_pipeline_review_stage ? [for subnet in data.aws_subnet.review : subnet.id] : []
    review_security_group_ids         = local.has_pipeline_review_stage ? [for security_group in data.aws_security_group.review : security_group.id] : []
    service_pipeline_configs          = local.service_pipeline_configs
    web_pipeline_configs              = local.web_pipeline_configs
    repo_configs                      = try(var.repo_configs, {})
  }
  tags = local.tags
}

module "waf" {
  source = "./waf"

  providers = {
    aws = aws.network_infra_role_for_cloudfront
  }

  configs = {
    backend_waf_name         = "${var.project_name}-api-waf-${var.stage}"
    frontend_waf_name        = "${var.project_name}-web-waf-${var.stage}"
    waf_ip_set_outbound_name = "kmutt-nat-outbound-ip-set"
  }
}

module "api_cdn" {
  source = "./backend-cdn"

  providers = {
    aws = aws.network_infra_role_for_cloudfront
  }

  certificate_arn = var.backend_configs.cloudfront_certificate_arn
  configs = {
    cf_name     = "${var.project_name}-api-cf-${var.stage}"
    web_acl_arn = module.waf.backend.arn
    associate_domains = [
      for api_config in local.api_configs : api_config.host_header_name
    ]
    default_origin = {
      name        = "external-alb"
      domain_name = module.external_lb.external_alb.lb_dns_name
      custom_origin_config = {
        http_port                = 80
        https_port               = 443
        origin_keepalive_timeout = 5
        origin_protocol_policy   = "https-only"
        origin_read_timeout      = 30
        origin_ssl_protocols = [
          "SSLv3",
          "TLSv1",
        ]
      }

      cache_behaviour = {
        allowed_methods         = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods          = ["GET", "HEAD"]
        compress                = true
        default_ttl             = 86400
        max_ttl                 = 31536000
        min_ttl                 = 0
        smooth_streaming        = false
        trusted_key_groups      = []
        trusted_signers         = []
        viewer_protocol_policy  = "redirect-to-https"
        headers                 = ["*"]
        query_string            = true
        query_string_cache_keys = []
        cookies_forward         = "all"
      }
    }
  }

  tags = local.tags
}

module "s3_web" {
  providers = {
    aws = aws.workload_infra_role
  }

  for_each = {
    for web_config in local.web_configs : "${web_config.bucket_name}" => web_config
  }

  source        = "terraform-aws-modules/s3-bucket/aws"
  bucket        = each.key
  force_destroy = true
}

resource "aws_s3_bucket_policy" "allow_access_from_cloudfront" {
  provider = aws.workload_infra_role

  for_each = {
    for web_config in local.web_configs : "${web_config.bucket_name}" => web_config
  }

  bucket = each.value.bucket_name
  policy = data.aws_iam_policy_document.allow_access_from_cloudfront[each.key].json
}

data "aws_iam_policy_document" "allow_access_from_cloudfront" {
  provider = aws.workload_infra_role

  for_each = {
    for web_config in local.web_configs : "${web_config.bucket_name}" => web_config
  }

  statement {
    sid = "PolicyForCloudFrontPrivateContent"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "arn:aws:s3:::${each.value.bucket_name}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = ["${module.web_cdn["${each.value.bucket_name}"].cloudfront.cloudfront_distribution_arn}"]
    }
  }
}

module "web_cdn" {
  for_each = {
    for web_config in local.web_configs : "${web_config.bucket_name}" => web_config
  }

  source = "./frontend-cdn"

  providers = {
    aws = aws.network_infra_role_for_cloudfront
  }

  certificate_arn = each.value.certificate_arn
  configs = {
    cf_name            = "${each.value.cloudfront_name}"
    web_acl_arn        = module.waf.frontend.arn
    associate_domains  = [each.value.host_header_name]
    root_object        = try(each.value.root_object, "index.html")
    bucket_name        = each.value.bucket_name
    bucket_domain_name = module.s3_web[each.value.bucket_name].s3_bucket_bucket_regional_domain_name
  }

  tags = local.tags
}

module "authentication" {
  for_each = local.authentication_configs

  providers = {
    aws = aws.workload_infra_role
  }

  source = "./authentication"

  configs = {
    user_pool_name           = "${each.value.user_pool_name}"
    password_minimum_length  = 6
    username_attributes      = ["email"]
    auto_verified_attributes = []
    required_user_attributes = ["email", "family_name", "given_name"]
    lambda_configs           = each.value.lambda_configs
    clients                  = each.value.clients
    tags                     = each.value.tags
  }

  tags = local.tags
}

module "automation" {
  count = length(try(var.automation_configs.projects, [])) > 1 ? 1 : 0

  providers = {
    aws = aws.workload_infra_role
  }

  source = "./automation"
  region = var.aws_region
  configs = {
    source_account_id = var.automation_configs.source_account_id
    s3_bucket_name    = var.automation_configs.s3_bucket_name
    assume_role_arn   = var.automation_configs.assume_role_arn
    projects          = var.automation_configs.projects
    pipeline_arns     = module.pipeline.pipeline_arns
    pipeline_mappings = var.automation_configs.pipeline_mappings
  }
  tags = local.tags
}
