module "api_gateway" "main_api_gateway" {
  source = "../../"

  name          = var.configs.name
  description   = var.configs.name
  protocol_type = "HTTP"

  cors_configuration = {
    allow_headers = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token", "x-amz-user-agent"]
    allow_methods = ["*"]
    allow_origins = ["*"]
  }

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
      vpc_link           = "my-vpc"
      integration_uri    = var.public_alb_http_tcp_listern_arn
      integration_type   = "HTTP_PROXY"
      integration_method = "ANY"
    }

    # "$default" = {
    #   lambda_arn = module.lambda_function.lambda_function_arn
    # }
  }

  vpc_links = {
    my-vpc = {
      name               = "example"
      security_group_ids = [module.api_gateway_security_group.security_group_id]
      subnet_ids         = module.vpc.public_subnets
    }
  }

  tags = {
    Name = "private-api"
  }
}

module "api_gateway_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "api-gateway-sg-${random_pet.this.id}"
  description = "API Gateway group for example usage"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp"]

  egress_rules = ["all-all"]
}
