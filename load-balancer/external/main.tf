# External Application Load Balancer
module "external_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "8.7.0"
  name    = var.configs.name

  load_balancer_type = "application"

  vpc_id                = var.vpc_id
  subnets               = var.configs.subnet_ids
  security_groups       = var.configs.security_group_ids
  internal              = false
  create_security_group = false
  # http_tcp_listeners = [
  #   {
  #     port        = 80
  #     protocol    = "HTTP"
  #     action_type = "redirect"
  #     redirect = {
  #       host        = "#{host}"
  #       path        = "/#{path}"
  #       port        = "443"
  #       protocol    = "HTTPS"
  #       query       = "#{query}"
  #       status_code = "HTTP_301"
  #     }
  #   }
  # ]

  https_listeners = [
    {
      port = 443
      # protocol           = "HTTPS"
      certificate_arn = var.certificate_arn
      # action_type        = "forward"
      # target_group_index = 0
    }
  ]

  https_listener_rules = [
    {
      https_listener_index = 0
      priority             = 2

      actions = [
        {
          type               = "forward"
          target_group_index = 0
        }
      ]

      conditions = [{
        host_headers = var.configs.allow_host_headers
      }]
    }
  ]

  target_groups = [
    {
      name             = var.configs.target_group_name
      backend_protocol = "HTTPS"
      backend_port     = 443
      target_type      = "ip"
    } # not register targets during the creation yet, use below lambda function to update target ips
  ]

  tags = merge(var.tags, { Name : var.configs.name })
}


resource "aws_cloudformation_stack" "lambda_register_targets" {
  name         = "StaticIPforALB-${var.configs.name}"
  template_url = "https://s3.amazonaws.com/exampleloadbalancer-us-east-1/blog-posts/static-ip-for-application-load-balancer/template_poplulate_NLB_TG_with_ALB_python3.json"

  capabilities = [
    "CAPABILITY_AUTO_EXPAND",
    "CAPABILITY_IAM",
    "CAPABILITY_NAMED_IAM",
  ]

  parameters = {
    "ALBListenerPort"    = "443"
    "InternalALBDNSName" = var.configs.internal_dns_name
    "NLBTargetGroupARN"  = module.external_alb.target_group_arns[0]
    "Region"             = var.region
    "S3BucketName"       = "kmutt-lb-static-ip"
    "SameVPC"            = "False"
  }
}
