data "aws_rds_engine_version" "postgresql" {
  engine  = "aurora-postgresql"
  version = "15.3"
}

module "db" {
  source = "terraform-aws-modules/rds-aurora/aws"

  name              = var.configs.name
  engine            = data.aws_rds_engine_version.postgresql.engine
  engine_mode       = "provisioned"
  engine_version    = data.aws_rds_engine_version.postgresql.version
  port              = var.configs.port
  storage_encrypted = true
  master_username   = "postgres"

  vpc_id               = var.vpc_id

  create_security_group = false
  vpc_security_group_ids = var.configs.security_group_ids

  db_subnet_group_name = var.configs.subnet_group_name

  create_monitoring_role = false
  monitoring_interval = 60
  monitoring_role_arn = var.configs.monitoring_role_arn
  
  apply_immediately   = true
  skip_final_snapshot = true

  serverlessv2_scaling_configuration = {
    min_capacity = var.configs.min_capacity
    max_capacity = var.configs.max_capacity
  }

  instance_class = "db.serverless"

  instances = {
    for v in range(1, var.configs.num_instances + 1): 
      "instance-${v}" => { identifier = "${var.configs.name}-instance-${v}" }
  }

  tags   = merge(var.tags, { Name = var.configs.name })
}
