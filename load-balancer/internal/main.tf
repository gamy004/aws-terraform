# Private Application Load Balancer
# should link to <project>-<service>-tg-<stage>
module "private_alb" {
  source = "terraform-aws-modules/alb/aws"

  name = var.configs.private_alb_name

  load_balancer_type         = "application"
  enable_deletion_protection = false
  vpc_id                     = var.vpc_id
  subnets                    = var.configs.private_alb_subnet_ids
  security_groups            = var.configs.private_alb_security_group_ids
  internal                   = true
  create_security_group      = false
  https_listeners = [
    {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = var.certificate_arn
      action_type     = "fixed-response"
      fixed_response = {
        content_type = "text/plain"
        status_code  = 404
      }
    }
  ]

  tags = merge(var.tags, { Name : var.configs.private_alb_name })
}

# Private network load balancer
module "private_nlb" {
  source = "terraform-aws-modules/alb/aws"

  name = var.configs.private_nlb_name

  load_balancer_type = "network"

  vpc_id                = var.vpc_id
  subnets               = var.configs.private_nlb_subnet_ids
  internal              = true
  create_security_group = false

  http_tcp_listeners = [
    {
      port               = 443
      protocol           = "TCP"
      target_group_index = 0
    },
  ]

  target_groups = [
    {
      name             = var.configs.private_nlb_target_group_name
      backend_protocol = "TCP"
      backend_port     = 443
      target_type      = "alb"
      targets = {
        "private-alb" = {
          target_id = module.private_alb.lb_arn
        }
      }
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 10
      }
    }
  ]

  tags = merge(var.tags, { Name : var.configs.private_nlb_name })
}

# Public Application Load Balancer
# should link to <project>-api-gw-tg-<stage>
module "public_alb" {
  source = "terraform-aws-modules/alb/aws"

  name = var.configs.public_alb_name

  load_balancer_type = "application"

  vpc_id                     = var.vpc_id
  subnets                    = var.configs.public_alb_subnet_ids
  security_groups            = var.configs.public_alb_security_group_ids
  internal                   = true
  enable_deletion_protection = false
  create_security_group      = false

  http_tcp_listeners = [
    {
      port        = 80
      protocol    = "HTTP"
      action_type = "redirect"
      redirect = {
        host        = "#{host}"
        path        = "/#{path}"
        port        = "443"
        protocol    = "HTTPS"
        query       = "#{query}"
        status_code = "HTTP_301"
      }
    }
  ]

  https_listeners = [
    {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = var.certificate_arn
      action_type     = "fixed-response"
      fixed_response = {
        content_type = "text/plain"
        status_code  = 404
      }
    }
  ]

  tags = merge(var.tags, { Name : var.configs.public_alb_name })
}
