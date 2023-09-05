locals {
  iam_users = {
    for config in lookup(var.configs, "service_configs", []) : config.service_name => config
  }

  service_definitions = {
    for index, config in lookup(var.configs, "service_configs", []) : config.service_name => {
      desired_count             = try(config.desired_count, 1)
      cpu                       = try(config.service_cpu, 1024)
      memory                    = try(config.service_memory, 2048)
      subnet_ids                = var.configs.subnet_ids
      create_security_group     = false
      security_group_ids        = var.configs.security_group_ids
      create_task_exec_iam_role = false
      create_task_exec_policy   = false
      create_tasks_iam_role     = false
      task_exec_iam_role_arn    = aws_iam_role.task_execution[config.service_name].arn
      tasks_iam_role_arn        = aws_iam_role.task_execution[config.service_name].arn
      enable_autoscaling        = try(config.enable_autoscaling, false)
      autoscaling_min_capacity  = try(config.autoscaling_min_capacity, 1)
      autoscaling_max_capacity  = try(config.autoscaling_max_capacity, 5)
      load_balancer = {
        service = {
          target_group_arn = element(var.configs.target_group_arns, index)
          container_name   = "${config.service_name}"
          container_port   = 80
        }
      }
      container_definitions = {
        (config.service_name) = {
          cpu       = try(config.task_cpu, 512)
          memory    = try(config.task_memory, 1024)
          essential = true
          environment = [
            for variable_name, environment_variable in try(config.environment_variables, {}) : {
              name  = "${variable_name}"
              value = "${environment_variable.value}"
            } if environment_variable.type == "PLAINTEXT"
          ]
          secrets = [
            for variable_name, environment_variable in try(config.environment_variables, {}) : {
              name      = "${variable_name}"
              valueFrom = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${environment_variable.valueFrom}"
            } if environment_variable.type == "PARAMETER"
          ]
          image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${config.service_name}:latest"
          port_mappings = [
            {
              name          = "${config.service_name}-80-tcp"
              containerPort = 80
              protocol      = "tcp"
            }
          ]
          enable_cloudwatch_logging = try(config.enable_cloudwatch_logging, true)
          memory_reservation        = 100
        }
      }
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy" "cognito_access" {
  arn = "arn:aws:iam::aws:policy/AmazonESCognitoAccess"
}

data "aws_iam_policy" "task_execution" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "dynamodb_access" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:*"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_user" "service" {
  for_each = local.iam_users
  ignore_changes = [
    tags
  ]
  name = each.value.service_name
  tags = merge(var.tags, { Name : "${each.value.service_name}" })
}

resource "aws_iam_user_policy_attachment" "cognito_access" {
  for_each = aws_iam_user.service

  user       = each.value.name
  policy_arn = data.aws_iam_policy.cognito_access.arn
}

resource "aws_iam_user_policy" "dynamodb_access" {
  for_each = aws_iam_user.service

  name   = "${each.value.name}-policy"
  user   = each.value.name
  policy = data.aws_iam_policy_document.dynamodb_access.json
}

resource "aws_iam_role" "task_execution" {
  for_each = aws_iam_user.service

  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "ecs-tasks.amazonaws.com"
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
    data.aws_iam_policy.task_execution.arn
  ]
  max_session_duration = 3600
  name                 = "${each.value.name}-task-execution-role"
  path                 = "/"
  tags                 = merge(var.tags, { Name : "${each.value.name}-task-execution-role" })

  # inline_policy {}
}

module "ecs" {
  source       = "terraform-aws-modules/ecs/aws"
  cluster_name = var.configs.cluster_name
  cluster_settings = {
    name  = "containerInsights",
    value = "enabled"
  }
  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/ecs/${var.configs.cluster_name}"
      }
    }
  }

  services = local.service_definitions

  tags = merge(var.tags, { Name : var.configs.cluster_name })
}
