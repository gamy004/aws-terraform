data "aws_vpc_endpoint" "api_gateway_endpoint" {
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${var.region}.execute-api"
}

resource "aws_api_gateway_rest_api" "api" {
  name                         = var.configs.name
  description                  = "THe API Gateway for ${var.configs.name}"
  disable_execute_api_endpoint = true
  endpoint_configuration {
    types            = ["PRIVATE"]
    vpc_endpoint_ids = [data.aws_vpc_endpoint.api_gateway_endpoint.id]
  }

  body = jsonencode({
    openapi = "3.0.1"
    info = {
      title   = "example"
      version = "1.0"
    }
    paths = {
      "/" = {
        get = {
          x-amazon-apigateway-integration = {
            httpMethod           = "GET"
            payloadFormatVersion = "1.0"
            type                 = "HTTP_PROXY"
            uri                  = "https://${var.configs.private_nlb_dns_name}/"
          }
        }
      }
    }
  })

  tags = merge(var.tags, { Name = var.configs.name })
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# resource "aws_api_gateway_integration" "base" {
#   rest_api_id             = aws_api_gateway_rest_api.api.id
#   resource_id             = aws_api_gateway_resource.base.id
#   uri                     = "https://${var.configs.private_nlb_dns_name}/"
#   http_method             = aws_api_gateway_method.base.http_method
#   type                    = "HTTP_PROXY"
#   integration_http_method = "GET"
#   connection_type         = "VPC_LINK"
#   connection_id           = aws_api_gateway_vpc_link.vpc_link_to_nlb.id
# }

resource "aws_api_gateway_integration" "proxy" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.proxy.id
  uri                     = "https://${var.configs.private_nlb_dns_name}/{proxy}"
  http_method             = aws_api_gateway_method.proxy.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.vpc_link_to_nlb.id
  cache_key_parameters    = ["method.request.path.proxy"]
  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

data "aws_iam_policy_document" "api_access_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["execute-api:Invoke"]
    resources = ["${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:sourceVpce"
      values   = ["${data.aws_vpc_endpoint.api_gateway_endpoint.id}"]
    }
  }
}

resource "aws_api_gateway_rest_api_policy" "api_policy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  policy      = data.aws_iam_policy_document.api_access_policy.json
}

resource "aws_api_gateway_domain_name" "api_domain" {
  count = length(var.configs.api_configs)

  regional_certificate_arn = var.certificate_arn
  domain_name              = var.configs.api_configs[count.index].host_header_name
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(var.tags, try(var.configs.api_configs[count.index].tags, {}))
}

resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on  = [aws_api_gateway_rest_api_policy.api_policy]
  rest_api_id = aws_api_gateway_rest_api.api.id
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.api.body))
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "api_v1" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "v1"
}

resource "aws_api_gateway_base_path_mapping" "api_mapping" {
  count       = length(var.configs.api_configs)
  api_id      = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.api_v1.stage_name
  domain_name = var.configs.api_configs[count.index].host_header_name
}

resource "aws_api_gateway_method_settings" "api_settings" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.api_v1.stage_name
  method_path = "*/*"
  settings {
    metrics_enabled        = true
    data_trace_enabled     = true
    logging_level          = "ERROR"
    throttling_burst_limit = 100
    throttling_rate_limit  = 100
    caching_enabled        = false
  }
}

# module "api_gateway" {
#   source = "terraform-aws-modules/apigateway-v2/aws"

#   name          = var.configs.name
#   description   = var.configs.name
#   protocol_type = "HTTP"

#   cors_configuration = {
#     allow_headers = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token", "x-amz-user-agent"]
#     allow_methods = ["*"]
#     allow_origins = ["*"]
#   }

#   create_vpc_link             = false
#   create_api_domain_name      = false
#   domain_name                 = var.domain_name
#   domain_name_certificate_arn = var.certificate_arn

#   default_route_settings = {
#     detailed_metrics_enabled = true
#     throttling_burst_limit   = 100
#     throttling_rate_limit    = 100
#   }

#   integrations = {
#     # "ANY /" = {
#     #   lambda_arn             = module.lambda_function.lambda_function_arn
#     #   payload_format_version = "2.0"
#     #   timeout_milliseconds   = 12000
#     # }

#     "GET /" = {
#       connection_type    = "VPC_LINK"
#       connection_id      = aws_api_gateway_vpc_link.vpc_link_to_nlb.id
#       integration_uri    = var.configs.public_alb_http_tcp_listern_arn
#       integration_type   = "HTTP_PROXY"
#       integration_method = "GET"
#     }

#     "GET /{proxy+}" = {
#       connection_type    = "VPC_LINK"
#       connection_id      = aws_api_gateway_vpc_link.vpc_link_to_nlb.id
#       integration_uri    = var.configs.public_alb_http_tcp_listern_arn
#       integration_type   = "HTTP_PROXY"
#       integration_method = "GET"
#     }
#   }

#   tags = merge(var.tags, { Name = var.configs.name })
# }

resource "aws_api_gateway_vpc_link" "vpc_link_to_nlb" {
  name        = var.configs.vpc_link_name
  description = var.configs.vpc_link_name
  target_arns = [var.configs.private_nlb_target_group_arn]
  tags        = merge(var.tags, { Name = var.configs.vpc_link_name })
}
