# Public Application Load Balancer
module "public_alb" {
  source  = "terraform-aws-modules/alb/aws"

  providers = {
    aws = aws.workload
  }

  name = var.configs.public_alb_name

  load_balancer_type = "application"

  vpc_id          = var.workload_vpc_id
  subnets         = var.configs.public_alb_subnet_ids
  security_groups = var.configs.public_alb_security_group_ids
  internal        = true
  enable_deletion_protection = true
  https_listeners = [
    {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = var.workload_certificate_arn
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


data "aws_network_interfaces" "interface_list" {
  depends_on = [ module.public_alb ]

  provider = aws.workload

  filter {
    name   = "description"
    values = ["ELB ${module.public_alb.lb_arn_suffix}"]
  }

  filter {
    name   = "availability-zone"
    values = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
  }
}

data "aws_network_interface" "interfaces" {
  depends_on = [ data.aws_network_interfaces.interface_list ]

  provider = aws.workload

  count = length(data.aws_network_interfaces.interface_list)

  id = data.aws_network_interfaces.interface_list.ids[count.index]
}

# Private Application Load Balancer
module "private_alb" {
  providers = {
    aws = aws.workload
  }

  source  = "terraform-aws-modules/alb/aws"

  name = var.configs.private_alb_name

  load_balancer_type = "application"
  enable_deletion_protection = true
  vpc_id             = var.workload_vpc_id
  subnets            = var.configs.private_alb_subnet_ids
  security_groups    = var.configs.private_alb_security_group_ids
  internal = true

  https_listeners = [
    {
      port               = 443
      protocol           = "HTTPS"
      certificate_arn    = var.workload_certificate_arn
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

# External Application Load Balancer
module "external_alb" {
  depends_on = [ module.public_alb, data.aws_network_interface.interfaces ]

  source  = "terraform-aws-modules/alb/aws"

  providers = {
    aws = aws.network
  }

  name = var.configs.external_alb_name

  load_balancer_type = "application"

  vpc_id          = var.network_vpc_id
  subnets         = var.configs.external_alb_subnet_ids
  security_groups = var.configs.external_alb_security_group_ids
  internal        = false

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
      certificate_arn    = var.network_certificate_arn
      action_type        = "forward"
      target_group_index = 0
    }
  ]

  target_groups = [
    {
      name             = var.configs.external_alb_target_group_name
      backend_protocol = "HTTPS"
      backend_port     = 443
      target_type      = "ip"
      targets = [
        for intf in data.aws_network_interface.interfaces : {
          target_id         = intf.private_ip
          port              = 443
          availability_zone = "all"
        }
      ]
    }
  ]

  tags = merge(var.tags, { Name: var.configs.external_alb_name })
}

resource "aws_cloudformation_stack" "lambda_register_targets" {
  provider = aws.network
  depends_on = [ module.public_alb, module.external_alb ]
  name         = "StaticIPforALB-${var.configs.external_alb_name}"
  template_url = "https://s3.amazonaws.com/exampleloadbalancer-us-east-1/blog-posts/static-ip-for-application-load-balancer/template_poplulate_NLB_TG_with_ALB_python3.json"

  capabilities = [
    "CAPABILITY_AUTO_EXPAND",
    "CAPABILITY_IAM",
    "CAPABILITY_NAMED_IAM",
  ]

  parameters = {
    "ALBListenerPort"    = "443"
    "InternalALBDNSName" = module.public_alb.lb_dns_name
    "NLBTargetGroupARN"  = module.external_alb.target_group_arns[0]
    "Region"             = "ap-southeast-1"
    "S3BucketName"       = "kmutt-lb-static-ip"
    "SameVPC"            = "False"
  }
}