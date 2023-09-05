locals {
  api_gateway_configs = {
    for api_config in var.configs.api_configs : api_config.api_gateway_name => api_config
  }
}
data "aws_vpc_endpoint" "api_gateway_endpoint" {
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${var.region}.execute-api"
}

resource "aws_api_gateway_vpc_link" "vpc_link_to_nlb" {
  name        = var.configs.vpc_link_name
  description = var.configs.vpc_link_name
  target_arns = [var.configs.private_nlb_target_group_arn]
  tags        = merge(var.tags, { Name = var.configs.vpc_link_name })
}

resource "aws_api_gateway_rest_api" "api" {
  for_each                     = local.api_gateway_configs
  name                         = each.key
  description                  = "THe API Gateway for ${each.key}"
  disable_execute_api_endpoint = true
  put_rest_api_mode            = "merge"
  endpoint_configuration {
    types            = ["PRIVATE"]
    vpc_endpoint_ids = var.configs.vpc_endpoint_ids
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
            uri                  = "https://${each.value.host_header_name}/"
            connectionType       = "VPC_LINK"
            connectionId         = aws_api_gateway_vpc_link.vpc_link_to_nlb.id
          }
        }
      }
    }
  })

  tags = merge(var.tags, { Name = each.key })
}

resource "aws_api_gateway_resource" "proxy" {
  for_each    = local.api_gateway_configs
  rest_api_id = aws_api_gateway_rest_api.api[each.key].id
  parent_id   = aws_api_gateway_rest_api.api[each.key].root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  for_each      = local.api_gateway_configs
  rest_api_id   = aws_api_gateway_rest_api.api[each.key].id
  resource_id   = aws_api_gateway_resource.proxy[each.key].id
  http_method   = "ANY"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_method" "proxy_options" {
  for_each      = local.api_gateway_configs
  rest_api_id   = aws_api_gateway_rest_api.api[each.key].id
  resource_id   = aws_api_gateway_resource.proxy[each.key].id
  http_method   = "OPTIONS"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "proxy" {
  for_each                = local.api_gateway_configs
  rest_api_id             = aws_api_gateway_rest_api.api[each.key].id
  resource_id             = aws_api_gateway_resource.proxy[each.key].id
  uri                     = "https://${each.value.host_header_name}/{proxy}"
  http_method             = aws_api_gateway_method.proxy[each.key].http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.vpc_link_to_nlb.id
  cache_key_parameters    = ["method.request.path.proxy"]
  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

resource "aws_api_gateway_integration" "proxy_options" {
  for_each    = local.api_gateway_configs
  rest_api_id = aws_api_gateway_rest_api.api[each.key].id
  resource_id = aws_api_gateway_resource.proxy[each.key].id
  http_method = aws_api_gateway_method.proxy_options[each.key].http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_method_response" "proxy_method_response" {
  for_each    = local.api_gateway_configs
  rest_api_id = aws_api_gateway_rest_api.api[each.key].id
  resource_id = aws_api_gateway_resource.proxy[each.key].id
  http_method = aws_api_gateway_method.proxy[each.key].http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Credentials" = true
  }
}

resource "aws_api_gateway_method_response" "proxy_options_method_response" {
  for_each    = local.api_gateway_configs
  rest_api_id = aws_api_gateway_rest_api.api[each.key].id
  resource_id = aws_api_gateway_resource.proxy[each.key].id
  http_method = aws_api_gateway_method.proxy_options[each.key].http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "proxy_options_integration_response" {
  for_each         = local.api_gateway_configs
  rest_api_id      = aws_api_gateway_rest_api.api[each.key].id
  resource_id      = aws_api_gateway_resource.proxy[each.key].id
  http_method      = aws_api_gateway_method.proxy_options[each.key].http_method
  status_code      = aws_api_gateway_method_response.proxy_options_method_response[each.key].status_code
  content_handling = "CONVERT_TO_TEXT"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token,sentry-trace,baggage'"
    "method.response.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "method.response.header.Access-Control-Allow-Origin"  = length(each.value.allowed_origins) > 0 ? join(",", each.value.allowed_origins) : "'*'"
  }
}

data "aws_iam_policy_document" "api_access_policy" {
  for_each = local.api_gateway_configs
  statement {
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["execute-api:Invoke"]
    resources = ["${aws_api_gateway_rest_api.api[each.key].execution_arn}/*/*/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:sourceVpce"
      values   = ["${data.aws_vpc_endpoint.api_gateway_endpoint.id}"]
    }
  }
}

resource "aws_api_gateway_rest_api_policy" "api_policy" {
  for_each    = local.api_gateway_configs
  rest_api_id = aws_api_gateway_rest_api.api[each.key].id
  policy      = data.aws_iam_policy_document.api_access_policy[each.key].json
}

resource "aws_api_gateway_domain_name" "api_domain" {
  for_each                 = local.api_gateway_configs
  regional_certificate_arn = var.certificate_arn
  domain_name              = each.value.host_header_name
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(var.tags, try(each.value.tags, {}))
}

resource "aws_api_gateway_deployment" "api_deployment" {
  for_each    = local.api_gateway_configs
  depends_on  = [aws_api_gateway_rest_api_policy.api_policy]
  rest_api_id = aws_api_gateway_rest_api.api[each.key].id
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.api[each.key].body,
      aws_api_gateway_resource.proxy[each.key].id,
      aws_api_gateway_method.proxy[each.key].id,
      aws_api_gateway_method.proxy_options[each.key].id,
      aws_api_gateway_integration.proxy[each.key].id,
      aws_api_gateway_integration.proxy_options[each.key].id,
      aws_api_gateway_method_response.proxy_method_response[each.key].id,
      aws_api_gateway_method_response.proxy_options_method_response[each.key].id,
      aws_api_gateway_integration_response.proxy_options_integration_response[each.key].id
    ]))
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "api_v1" {
  for_each      = local.api_gateway_configs
  deployment_id = aws_api_gateway_deployment.api_deployment[each.key].id
  rest_api_id   = aws_api_gateway_rest_api.api[each.key].id
  stage_name    = "v1"
}

resource "aws_api_gateway_base_path_mapping" "api_mapping" {
  for_each    = local.api_gateway_configs
  api_id      = aws_api_gateway_rest_api.api[each.key].id
  stage_name  = aws_api_gateway_stage.api_v1[each.key].stage_name
  domain_name = each.value.host_header_name
}

resource "aws_api_gateway_method_settings" "api_settings" {
  for_each    = local.api_gateway_configs
  rest_api_id = aws_api_gateway_rest_api.api[each.key].id
  stage_name  = aws_api_gateway_stage.api_v1[each.key].stage_name
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
