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
          image     = try(config.image, "public.ecr.aws/lts/apache2:2.4-20.04_beta")
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

resource "aws_iam_user" "service" {
  for_each = local.iam_users
  name     = each.value.service_name
  tags     = merge(var.tags, { Name : "${each.value.service_name}" })
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
  # fargate_capacity_providers = {
  #   FARGATE = {
  #     default_capacity_provider_strategy = {
  #       weight = 50
  #       base   = 20
  #     }
  #   }
  #   FARGATE_SPOT = {
  #     default_capacity_provider_strategy = {
  #       weight = 50
  #     }
  #   }
  # }

  services = local.service_definitions

  # services = {
  #   ecsdemo-frontend = {
  #     cpu    = 1024
  #     memory = 4096

  #     # Container definition(s)
  #     container_definitions = {

  #       fluent-bit = {
  #         cpu       = 512
  #         memory    = 1024
  #         essential = true
  #         image     = "906394416424.dkr.ecr.us-west-2.amazonaws.com/aws-for-fluent-bit:stable"
  #         firelens_configuration = {
  #           type = "fluentbit"
  #         }
  #         memory_reservation = 50
  #       }

  #       ecs-sample = {
  #         cpu       = 512
  #         memory    = 1024
  #         essential = true
  #         image     = "public.ecr.aws/lts/apache2:2.4-20.04_beta"
  #         port_mappings = [
  #           {
  #             name          = "ecs-sample"
  #             containerPort = 80
  #             protocol      = "tcp"
  #           }
  #         ]

  #         # Example image used requires access to write to root filesystem
  #         readonly_root_filesystem = false

  #         dependencies = [{
  #           containerName = "fluent-bit"
  #           condition     = "START"
  #         }]

  #         enable_cloudwatch_logging = false
  #         log_configuration = {
  #           logDriver = "awsfirelens"
  #           options = {
  #             Name                    = "firehose"
  #             region                  = "eu-west-1"
  #             delivery_stream         = "my-stream"
  #             log-driver-buffer-limit = "2097152"
  #           }
  #         }
  #         memory_reservation = 100
  #       }
  #     }

  #     # service_connect_configuration = {
  #     #   namespace = "example"
  #     #   service = {
  #     #     client_alias = {
  #     #       port     = 80
  #     #       dns_name = "ecs-sample"
  #     #     }
  #     #     port_name      = "ecs-sample"
  #     #     discovery_name = "ecs-sample"
  #     #   }
  #     # }

  #     load_balancer = {
  #       service = {
  #         target_group_arn = var.configs
  #         container_name   = "ecs-sample"
  #         container_port   = 80
  #       }
  #     }

  #     subnet_ids = ["subnet-abcde012", "subnet-bcde012a", "subnet-fghi345a"]
  #     security_group_rules = {
  #       alb_ingress_3000 = {
  #         type                     = "ingress"
  #         from_port                = 80
  #         to_port                  = 80
  #         protocol                 = "tcp"
  #         description              = "Service port"
  #         source_security_group_id = "sg-12345678"
  #       }
  #       egress_all = {
  #         type        = "egress"
  #         from_port   = 0
  #         to_port     = 0
  #         protocol    = "-1"
  #         cidr_blocks = ["0.0.0.0/0"]
  #       }
  #     }
  #   }
  # }

  tags = merge(var.tags, { Name : var.configs.cluster_name })
}
