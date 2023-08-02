# resource "aws_lb_target_group" "target_group" {
#   name              = var.configs.target_group_name
#   protocol          = "HTTPS"
#   port              = 443
#   target_type       = "ip"
# }

# resource "aws_lb_target_group_attachment" "target_group_attachments" {
#   for_each = data.dns_a_record_set.internal_ips.addrs

#   target_group_arn  = aws_lb_target_group.target_group.arn
#   target_id         = each.value
#   port              = 80
#   availability_zone = "all"
# }

data "aws_network_interface" "internal_eni_a" {

  filter {
    name   = "description"
    values = ["ELB ${var.configs.internal_lb_arn}"]
  }

  filter {
    name = "vpc-id"
    values = ["${var.vpc_id}"]
  }

  filter {
    name   = "subnet-id"
    values = [var.configs.subnet_a]
  }
}

# External Application Load Balancer
module "external_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "8.7.0"
  name = var.configs.name

  load_balancer_type = "application"

  vpc_id          = var.vpc_id
  subnets         = var.configs.subnet_ids
  security_groups = var.configs.security_group_ids
  internal        = false
  create_security_group = false
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

      # targets = [
      #   {
      #     target_id         = "172.28.69.130"
      #     port              = 443
      #     availability_zone = "all"
      #   }
      # ]
      
      targets = {
        "target-a" = {
          target_id = data.aws_network_interface.internal_eni_a.private_ip,
          port = 443
          availability_zone = "all"
        }
        # for key, value in var.configs.internal_ips :
        #   "target-${key}" => {
        #     target_id         = value
        #     port              = 443
        #     availability_zone = "all"
        #   }
      }
    }
  ]

  tags = merge(var.tags, { Name: var.configs.name })
}

# resource "aws_cloudformation_stack" "lambda_register_targets" {
#   name         = "StaticIPforALB-${var.configs.name}"
#   template_url = "https://s3.amazonaws.com/exampleloadbalancer-us-east-1/blog-posts/static-ip-for-application-load-balancer/template_poplulate_NLB_TG_with_ALB_python3.json"

#   capabilities = [
#     "CAPABILITY_AUTO_EXPAND",
#     "CAPABILITY_IAM",
#     "CAPABILITY_NAMED_IAM",
#   ]

#   parameters = {
#     "ALBListenerPort"    = "443"
#     "InternalALBDNSName" = var.configs.internal_dns_name
#     "NLBTargetGroupARN"  = aws_lb_target_group.target_group.arn
#     "Region"             = "ap-southeast-1"
#     "S3BucketName"       = "kmutt-lb-static-ip"
#     "SameVPC"            = "False"
#   }
# }