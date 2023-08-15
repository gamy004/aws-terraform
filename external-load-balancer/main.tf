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

  https_listeners = [
    {
      port               = 443
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
      tags             = merge(var.tags, { Name : var.configs.target_group_name })
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
    "InternalALBDNSName" = var.configs.internal_public_alb_dns_name
    "NLBTargetGroupARN"  = module.external_alb.target_group_arns[0]
    "Region"             = var.region
    "S3BucketName"       = "kmutt-lb-static-ip"
    "SameVPC"            = "False"
  }
}
