locals {
  private_alb_https_listener_rules = [
    for index, api_config in var.configs.api_configs : {
      https_listener_index = 0
      priority             = index + 1
      actions = [
        {
          type               = "forward"
          target_group_index = index
        }
      ]
      conditions = [{
        host_headers = [api_config.host_header_name]
      }]
      tags = merge(var.tags, try(api_config.tags, {}), { Name = api_config.target_group_name })
    }
  ]

  private_alb_target_groups = [
    for api_config in var.configs.api_configs : {
      name             = api_config.target_group_name
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "ip"
      tags             = merge(var.tags, try(api_config.tags, {}), { Name = api_config.target_group_name })
    }
  ]

  private_nlb_http_tcp_listeners = [
    {
      port               = 443
      protocol           = "TCP"
      target_group_index = 0
    },
  ]

  private_nlb_target_groups = [
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
        protocol            = "HTTPS"
        interval            = 30
        path                = "/"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 10
      }
      tags = merge(var.tags, { Name = var.configs.private_nlb_target_group_name })
    }
  ]

  all_api_gateway_network_interface_ids = flatten([
    for endpoint in data.aws_vpc_endpoint.api_gateway_endpoints : [
      for network_interface_id in endpoint.network_interface_ids : network_interface_id
    ]
  ])

  public_alb_target_groups = [
    {
      name             = var.configs.public_alb_target_group_name
      backend_protocol = "HTTPS"
      backend_port     = 443
      target_type      = "ip"
      targets = {
        for network_interface in data.aws_network_interface.api_gateway_endpoints : network_interface.subnet_id => {
          target_id         = network_interface.private_ip
          port              = 443
          availability_zone = network_interface.availability_zone
        }
      }
      health_check = {
        enabled             = true
        protocol            = "HTTPS"
        interval            = 30
        path                = "/"
        port                = "traffic-port"
        healthy_threshold   = 5
        unhealthy_threshold = 3
        timeout             = 5
        matcher             = "200-403"
      }
    } # not register targets during the creation yet, use below lambda function to update target ips
  ]
}

data "aws_vpc_endpoint" "api_gateway_endpoints" {
  for_each = toset(var.configs.api_gateway_vpc_endpoint_ids)
  id       = each.value
}

data "aws_network_interface" "api_gateway_endpoints" {
  for_each = toset(local.all_api_gateway_network_interface_ids)
  id       = each.value
}

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
        status_code  = 200
      }
    }
  ]

  https_listener_rules = local.private_alb_https_listener_rules

  target_groups = local.private_alb_target_groups

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

  http_tcp_listeners = local.private_nlb_http_tcp_listeners

  target_groups = local.private_nlb_target_groups

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
      port               = 443
      protocol           = "HTTPS"
      certificate_arn    = var.certificate_arn
      action_type        = "forward"
      target_group_index = 0
    }
  ]

  target_groups = local.public_alb_target_groups

  tags = merge(var.tags, { Name : var.configs.public_alb_name })
}
