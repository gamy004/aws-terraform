# Private Application Load Balancer
module "private_alb" {
  source  = "terraform-aws-modules/alb/aws"

  name = var.configs.private_alb_name

  load_balancer_type = "application"
  enable_deletion_protection = false
  vpc_id             = var.vpc_id
  subnets            = var.configs.private_alb_subnet_ids
  security_groups    = var.configs.private_alb_security_group_ids
  internal = true
  create_security_group = false
  https_listeners = [
    {
      port               = 443
      protocol           = "HTTPS"
      certificate_arn    = var.certificate_arn
      action_type = "fixed-response"
      fixed_response = {
        content_type = "text/plain"
        status_code  = 200
        message_body = "OK"
      }
    }
  ]

  tags = merge(var.tags, { Name: var.configs.private_alb_name })
}

# Public Application Load Balancer
module "public_alb" {
  source  = "terraform-aws-modules/alb/aws"

  name = var.configs.public_alb_name

  load_balancer_type = "application"

  vpc_id          = var.vpc_id
  subnets         = var.configs.public_alb_subnet_ids
  security_groups = var.configs.public_alb_security_group_ids
  internal        = true
  enable_deletion_protection = false
  create_security_group = false
  https_listeners = [
    {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = var.certificate_arn
      action_type     = "fixed-response"
      fixed_response = {
        content_type = "text/plain"
        status_code  = 200
        message_body = "OK"
      }
    }
  ]

  tags = merge(var.tags, { Name: var.configs.public_alb_name })
}


# data "aws_network_interface" "public_network_interfaces" {
#   depends_on = [module.public_alb]

#   for_each = toset(var.configs.public_alb_subnet_ids)

#   filter {
#     name   = "description"
#     values = ["ELB ${module.public_alb.lb_arn_suffix}"]
#   }

#   filter {
#     name = "vpc-id"
#     values = ["${var.vpc_id}"]
#   }

#   filter {
#     name   = "subnet-id"
#     values = [each.value]
#   }
# }

# locals {
#   lb_id_name = "${module.public_alb.lb_id}|${module.public_alb.lb_arn_suffix}"
#   lb_computed_name = split("|", local.lb_id_name)[1]
# }

# data "aws_network_interface" "public_network_interfaces" {
#   for_each = toset(var.configs.public_alb_subnet_ids)

#   filter {
#     name   = "description"
#     values = ["ELB ${local.lb_computed_name}"]
#   }

#   filter {
#     name = "vpc-id"
#     values = [var.vpc_id]
#   }
#   filter {
#     name = "status"
#     values = ["in-use"]
#   }
#   filter {
#     name = "attachment.status"
#     values = ["attached"]
#   }

#   filter {
#     name   = "subnet-id"
#     values = [each.value]
#   }
# }