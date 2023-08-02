# Private Application Load Balancer
module "private_alb" {
  source  = "terraform-aws-modules/alb/aws"

  name = var.configs.private_alb_name

  load_balancer_type = "application"
  enable_deletion_protection = true
  vpc_id             = var.vpc_id
  subnets            = var.configs.private_alb_subnet_ids
  security_groups    = var.configs.private_alb_security_group_ids
  internal = true

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
  enable_deletion_protection = true
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

data "aws_network_interface" "network_interface_az_a" {
  filter {
    name   = "description"
    values = ["ELB ${module.public_alb.lb_arn_suffix}"]
  }

  filter {
    name   = "availability-zone"
    values = ["ap-southeast-1a"]
  }
}

data "aws_network_interface" "network_interface_az_b" {
  filter {
    name   = "description"
    values = ["ELB ${module.public_alb.lb_arn_suffix}"]
  }

  filter {
    name   = "availability-zone"
    values = ["ap-southeast-1b"]
  }
}

data "aws_network_interface" "network_interface_az_c" {
  filter {
    name   = "description"
    values = ["ELB ${module.public_alb.lb_arn_suffix}"]
  }

  filter {
    name   = "availability-zone"
    values = ["ap-southeast-1c"]
  }
}
