locals {
  iam_users = {
    for config in lookup(var.configs, "service_configs", []) : config.service_name => config
  }

  service_definitions = {
    for index, config in lookup(var.configs, "service_configs", []) : config.service_name => {
      desired_count            = try(config.desired_count, 1)
      cpu                      = try(config.service_cpu, 1024)
      memory                   = try(config.service_memory, 2048)
      subnet_ids               = var.configs.subnet_ids
      create_security_group    = false
      security_group_ids       = var.configs.security_group_ids
      enable_autoscaling       = try(config.enable_autoscaling, false)
      autoscaling_min_capacity = try(config.autoscaling_min_capacity, 1)
      autoscaling_max_capacity = try(config.autoscaling_max_capacity, 5)
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
              type  = "${environment_variable.type}"
              value = "${environment_variable.value}"
            }
          ]
          image = "${var.ecr_repositories[config.service_name].repository_url}:latest"
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

data "aws_iam_policy" "cognito_access" {
  arn = "arn:aws:iam::aws:policy/AmazonESCognitoAccess"
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

# resource "aws_iam_user" "service" {
#   for_each = local.iam_users
#   name     = each.value.service_name
#   tags     = merge(var.tags, { Name : "${each.value.service_name}" })
# }

# resource "aws_iam_user_policy_attachment" "cognito_access" {
#   for_each = aws_iam_user.service

#   user       = each.value.name
#   policy_arn = data.aws_iam_policy.cognito_access.arn
# }

# resource "aws_iam_user_policy" "dynamodb_access" {
#   for_each = aws_iam_user.service

#   name   = "${each.value.name}-policy"
#   user   = each.value.name
#   policy = data.aws_iam_policy_document.dynamodb_access.json
# }

# module "ecs" {
#   source       = "terraform-aws-modules/ecs/aws"
#   cluster_name = var.configs.cluster_name
#   cluster_settings = {
#     name  = "containerInsights",
#     value = "enabled"
#   }
#   cluster_configuration = {
#     execute_command_configuration = {
#       logging = "OVERRIDE"
#       log_configuration = {
#         cloud_watch_log_group_name = "/ecs/${var.configs.cluster_name}"
#       }
#     }
#   }

#   services = local.service_definitions

#   tags = merge(var.tags, { Name : var.configs.cluster_name })
# }
