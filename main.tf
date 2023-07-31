provider "aws" {
  region  = "ap-southeast-1"
}

locals {
  name = "ct4life"

  tags = {
    Name = local.name
    Environment = var.stage
    Terraform = true
  }
}

data "aws_vpc" "selected" {
  filter {
    name = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_rds_engine_version" "postgresql" {
  engine  = "aurora-postgresql"
  version = "15.3"
}

module "db" {
  source = "terraform-aws-modules/rds-aurora/aws"

  name              = "${local.name}-${var.db.name}-${var.stage}"
  engine            = data.aws_rds_engine_version.postgresql.engine
  engine_mode       = "provisioned"
  engine_version    = data.aws_rds_engine_version.postgresql.version
  storage_encrypted = true
  master_username   = "postgres"

  vpc_id               = data.aws_vpc.selected.id

  create_security_group = false
  vpc_security_group_ids = var.db.security_group_ids

  db_subnet_group_name = var.db.database_subnet_group_name

  create_monitoring_role = false
  monitoring_interval = 60
  monitoring_role_arn = var.db.monitoring_role_arn
  
  apply_immediately   = true
  skip_final_snapshot = true

  serverlessv2_scaling_configuration = {
    min_capacity = var.db.min_capacity
    max_capacity = var.db.max_capacity
  }

  instance_class = "db.serverless"
  instances = {
    for v in range(1, var.db.num_instances): 
      v => { identifier = "${local.name}-${var.db.name}-${var.stage}-instance-${v}" }
  }

  tags = local.tags
}
