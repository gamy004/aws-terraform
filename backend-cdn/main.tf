module "cf" {
  source = "terraform-aws-modules/cloudfront/aws"

  aliases = var.configs.associate_domains

  comment             = var.configs.cf_name
  enabled             = true
  http_version        = "http2and3"
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  wait_for_deployment = true
  web_acl_id          = var.configs.web_acl_arn

  origin = {
    "${var.configs.default_origin.name}" = {
      domain_name          = var.configs.default_origin.domain_name
      custom_origin_config = try(var.configs.default_origin.custom_origin_config, {})
    }
  }

  default_cache_behavior = merge(
    { target_origin_id = var.configs.default_origin.name },
    try(var.configs.default_origin.cache_behaviour, {})
  )

  viewer_certificate = {
    acm_certificate_arn            = var.certificate_arn
    cloudfront_default_certificate = false
    minimum_protocol_version       = "TLSv1.2_2019"
    ssl_support_method             = "sni-only"
  }

  tags = merge(var.tags, { Name : "${var.configs.cf_name}" })
}
