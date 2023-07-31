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

  vpc_id               = var.vpc.id
  vpc_security_group_ids = var.db.security_group_ids
  # db_subnet_group_name = var.vpc.database_subnet_group_name

  monitoring_interval = 60

  apply_immediately   = true
  skip_final_snapshot = true

  serverlessv2_scaling_configuration = {
    min_capacity = var.db.min_capacity
    max_capacity = var.db.max_capacity
  }

  instance_class = "db.serverless"
  instances = {
    one = {}
    two = {}
  }

  tags = local.tags
}
