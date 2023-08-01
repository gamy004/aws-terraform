locals {
  name = "ct4life"

  tags = {
    Name = local.name
    Environment = var.stage
    Terraform = true
  }
}

provider "aws" {
  alias   = "database_role"
  assume_role {
    role_arn = "arn:aws:iam::${var.workload_account_id}:role/KMUTTDatabaseRole"
  }
}

provider "aws" {
  alias   = "infra_role"
  assume_role {
    role_arn = "arn:aws:iam::${var.workload_account_id}:role/KMUTTInfraRole"
  }
}

provider "aws" {
  alias   = "security_role"
  assume_role {
    role_arn = "arn:aws:iam::${var.workload_account_id}:role/KMUTTSecurityRole"
  }
}

data "aws_iam_account_alias" "workload_account_alias" {
  provider = aws.infra_role
}

data "aws_vpc" "workload_vpc" {
  provider = aws.infra_role
  filter {
    name = "tag:Name"
    values = ["${data.aws_iam_account_alias.workload_account_alias.account_alias}-vpc"]
  }
}

module "security_groups" {
  source = "./seceruity-group"

  providers = {
    aws = aws.security_role
  }

  vpc_id = data.aws_vpc.workload_vpc.id
  configs = merge(
    var.sg_configs,
    {
      secure_security_group_name = "${local.name}-secure-sg-${var.stage}"
      app_security_group_name = "${local.name}-app-sg-${var.stage}"
      public_alb_security_group_name = "${local.name}-alb-sg-${var.stage}"
      private_alb_security_group_name = "${local.name}-nonexpose-alb-sg-${var.stage}"
      db_port = var.db_configs.port
    }
  )
  tags = local.tags
}

module "database" {
  depends_on = [ module.security_groups ]
  source = "./database"

  providers = {
    aws = aws.database_role
  }

  vpc_id = data.aws_vpc.workload_vpc.id
  configs = merge(
    var.db_configs,
    {
      name = "${local.name}-${var.db_configs.name}-${var.stage}"
      monitoring_role_arn = "arn:aws:iam::${var.workload_account_id}:role/rds-monitoring-role"
      security_group_ids = [module.security_groups.secure_sg.id]
    }
  )
  tags = local.tags
}
