locals {
  tags = {
    Project   = var.project_name
    Stage     = var.stage
    Terraform = true
  }
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
# module "api_gateway" {
#   source = "./api-gateway"

#   providers = {
#     aws = aws.workload_infra_role
#   }

#   vpc_id          = data.aws_vpc.workload_vpc.id
#   certificate_arn = data.aws_acm_certificate.workload_certificate.arn
#   domain_name     = var.domain_name
#   configs = {
#     name                            = "${var.project_name}-api-gw-${var.stage}"
#     vpc_link_name                   = "${var.project_name}-vpclink-${var.stage}"
#     public_alb_http_tcp_listern_arn = module.internal_lb.public_alb.http_tcp_listener_arns[0]
#     private_nlb_target_group_arn    = module.internal_lb.private_nlb.lb_arn
#   }
#   tags = local.tags
# }

## Database
# module "database" {
#   depends_on = [module.security_groups]
#   source     = "./database"

#   providers = {
#     aws = aws.workload_database_role
#   }

#   vpc_id = data.aws_vpc.workload_vpc.id
#   configs = merge(
#     var.db_configs,
#     {
#       name                = "${var.project_name}-${var.db_configs.name}-${var.stage}"
#       monitoring_role_arn = "arn:aws:iam::${var.workload_account_id}:role/rds-monitoring-role"
#       security_group_ids  = [module.security_groups.secure_sg.id]
#     }
#   )
#   tags = local.tags
# }
