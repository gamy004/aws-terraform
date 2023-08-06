module "api_gateway" {
  source = "terraform-aws-modules/apigateway-v2/aws"

  name          = var.configs.name
  description   = var.configs.name
  protocol_type = "HTTP"

  cors_configuration = {
    allow_headers = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token", "x-amz-user-agent"]
    allow_methods = ["*"]
    allow_origins = ["*"]
  }

  create_vpc_link             = false
  create_api_domain_name      = false
  domain_name                 = var.domain_name
  domain_name_certificate_arn = var.certificate_arn

  default_route_settings = {
    detailed_metrics_enabled = true
    throttling_burst_limit   = 100
    throttling_rate_limit    = 100
  }

  integrations = {
    # "ANY /" = {
    #   lambda_arn             = module.lambda_function.lambda_function_arn
    #   payload_format_version = "2.0"
    #   timeout_milliseconds   = 12000
    # }

    "GET /" = {
      connection_type    = "VPC_LINK"
      vpc_link           = "${var.configs.vpc_link_name}"
      integration_uri    = var.configs.public_alb_http_tcp_listern_arn
      integration_type   = "HTTP_PROXY"
      integration_method = "GET"
    }

    "GET /{proxy+}" = {
      connection_type    = "VPC_LINK"
      vpc_link           = "${var.configs.vpc_link_name}"
      integration_uri    = var.configs.public_alb_http_tcp_listern_arn
      integration_type   = "HTTP_PROXY"
      integration_method = "GET"
    }

    # "$default" = {
    #   lambda_arn = module.lambda_function.lambda_function_arn
    # }
  }

  # vpc_links = {
  #   main_vpc_link = {
  #     name        = "${var.configs.vpc_link_name}"
  #     target_arns = [var.configs.public_alb_http_tcp_listern_arn]
  #     # security_group_ids = ["${var.configs.private_nlb_}"]
  #     # subnet_ids         = module.vpc.public_subnets
  #   }
  # }

  tags = merge(var.tags, { Name = var.configs.name })
}

resource "aws_api_gateway_vpc_link" "vpc_link_to_nlb" {
  name        = var.configs.vpc_link_name
  description = var.configs.vpc_link_name
  target_arns = [var.configs.public_alb_http_tcp_listern_arn]
}
