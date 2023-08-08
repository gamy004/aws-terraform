# data "aws_rds_engine_version" "postgresql" {
#   engine  = "aurora-postgresql"
#   version = "15.3"
# }
locals {
  aurora_dbs = {
    for k, v in var.configs : k => v if length(regexall("aurora-*", v.engine)) > 0
  }
}

module "db" {
  for_each = local.aurora_dbs

  source = "terraform-aws-modules/rds-aurora/aws"

  name                         = "${each.key}-db"
  engine_mode                  = "provisioned"
  engine                       = each.value.engine
  engine_version               = each.value.engine_version
  port                         = each.value.port
  deletion_protection          = each.value.deletion_protection
  performance_insights_enabled = true
  storage_encrypted            = true
  master_username              = "postgres"

  vpc_id = var.vpc_id

  create_security_group  = false
  vpc_security_group_ids = var.security_group_ids

  db_subnet_group_name = var.subnet_group_name

  create_monitoring_role = false
  monitoring_interval    = 60
  monitoring_role_arn    = var.monitoring_role_arn

  apply_immediately   = true
  skip_final_snapshot = true

  serverlessv2_scaling_configuration = {
    min_capacity = each.value.min_capacity
    max_capacity = each.value.max_capacity
  }

  instance_class = "db.serverless"

  instances = {
    for i in range(1, each.value.num_instances + 1) :
    "instance-${i}" => { identifier = "${each.key}-db-instance-${i}" }
  }

  tags = merge(var.tags, { Name = "${each.key}-db" })
}
