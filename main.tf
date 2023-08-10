locals {
  tags = {
    Project   = var.project_name
    Stage     = var.stage
    Terraform = true
  }

  api_configs = flatten([
    for environment in var.environments : [
      for application in var.applications : {
        host_header_name  = "${environment}-api-${application}.${var.domain_name}"
        target_group_name = "${application}-ecs-tg-${environment}"
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

  service_configs = flatten([
    for environment in var.environments : [
      for application in var.applications : merge(
        lookup(var.backend_configs, "${application}-${environment}", {}),
        {
          repo_name         = "${application}-service"
          service_name      = "${application}-service-${environment}"
          ci_build_name     = "${var.project_name}-${application}-ci-codebuild-${environment}"
          review_build_name = "${var.project_name}-${application}-review-codebuild-${environment}"
          pipeline_name     = "${var.project_name}-${application}-codepipeline-${environment}"
          environment_variables = {
            build = merge(
              local.default_environment_variables,
              lookup(var.build_configs.environment_variables, "all", {}),
              lookup(var.build_configs.environment_variables.build, "all", {}),
              lookup(var.build_configs.environment_variables.build, "${application}-service", {}),
              lookup(var.build_configs.environment_variables.build, "${application}-service-${environment}", {}),
            )
            review = merge(
              local.default_environment_variables,
              lookup(var.build_configs.environment_variables, "all", {}),
              lookup(var.build_configs.environment_variables.review, "${application}-service", {}),
              lookup(var.build_configs.environment_variables.review, "${application}-service-${environment}", {}),
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
  filter {
    name   = "tag:Name"
    values = ["${data.aws_iam_account_alias.workload_account_alias.account_alias}-app-b"]
  }
}

data "aws_db_subnet_group" "database" {
  provider = aws.workload_database_role
  name     = var.db_configs.subnet_group_name
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
    api_configs                    = local.api_configs
  }
  tags = local.tags
}

## External Load Balancer
# module "external_lb" {
#   source = "./external-load-balancer"

#   providers = {
#     aws = aws.network_infra_role
#   }

#   region          = var.aws_region
#   vpc_id          = data.aws_vpc.network_vpc.id
#   certificate_arn = data.aws_acm_certificate.network_certificate.arn
#   configs = {
#     name                         = "${var.project_name}-external-alb-${var.stage}"
#     target_group_name            = "${var.project_name}-external-alb-tg-${var.stage}"
#     security_group_ids           = [module.security_groups.external_alb_sg.id]
#     subnet_ids                   = data.aws_subnets.external_subnets.ids
#     internal_public_alb_dns_name = module.internal_lb.public_alb.lb_dns_name
#   }
#   tags = local.tags
# }

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

module "service" {
  source = "./service"

  providers = {
    aws = aws.workload_infra_role
  }

  region = var.aws_region
  vpc_id = data.aws_vpc.workload_vpc.id
  configs = {
    cluster_name       = "${var.project_name}-cluster-${var.stage}"
    subnet_ids         = data.aws_subnets.private_subnets.ids
    security_group_ids = [module.security_groups.app_sg.id]
    target_group_arns  = module.internal_lb.private_alb.target_group_arns
    service_configs    = local.service_configs
  }
  tags = local.tags
}

# resource "aws_s3_bucket" "pipeline" {
#   bucket = "${var.project_name}-artifacts"

#   tags = merge(var.tags, { Name : "${var.project_name}-artifacts" })
# }

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
    s3_artifact_bucket_name           = "${var.project_name}-artifacts"
    review_subnet                     = data.aws_subnet.review.arn
    service_configs                   = local.service_configs
    repo_configs                      = try(var.repo_configs, {})
  }
  tags = local.tags
}
