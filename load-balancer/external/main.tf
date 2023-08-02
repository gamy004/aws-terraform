# External Application Load Balancer
module "external_alb" {
  source  = "terraform-aws-modules/alb/aws"

  name = var.configs.name

  load_balancer_type = "application"

  vpc_id          = var.vpc_id
  subnets         = var.configs.subnet_ids
  security_groups = var.configs.security_group_ids
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
      certificate_arn    = var.certificate_arn
      action_type        = "forward"
      target_group_index = 0
    }
  ]

  target_groups = [
    {
      name             = var.configs.target_group_name
      backend_protocol = "HTTPS"
      backend_port     = 443
      target_type      = "ip"
      targets = [
        for ip in var.configs.internal_ips : {
          target_id         = ip
          port              = 443
          availability_zone = "all"
        }
      ]
    }
  ]

  tags = merge(var.tags, { Name: var.configs.name })
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
    "Region"             = "ap-southeast-1"
    "S3BucketName"       = "kmutt-lb-static-ip"
    "SameVPC"            = "False"
  }
}