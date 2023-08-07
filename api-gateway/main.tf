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
      title   = "${var.configs.name}"
      version = "${timestamp()}"
    }
    paths = {
      "/{proxy+}" : {
        "options" : {
          "parameters" : [{
            "name" : "proxy",
            "in" : "path",
            "required" : true,
            "schema" : {
              "type" : "string"
            }
          }],
          "responses" : {
            "200" : {
              "description" : "200 response",
              "headers" : {
                "Access-Control-Allow-Origin" : {
                  "schema" : {
                    "type" : "string"
                  }
                },
                "Access-Control-Allow-Methods" : {
                  "schema" : {
                    "type" : "string"
                  }
                },
                "Access-Control-Allow-Headers" : {
                  "schema" : {
                    "type" : "string"
                  }
                }
              },
              "content" : {}
            }
          }
        },
        "x-amazon-apigateway-any-method" : {
          "parameters" : [{
            "name" : "proxy",
            "in" : "path",
            "required" : true,
            "schema" : {
              "type" : "string"
            }
          }]
        }
      },
      "/" : {
        "get" : {}
      }
    }
  })
  tags = merge(var.tags, { Name = var.configs.name })
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
