
locals {
  origin_id = "${var.configs.bucket_name}_oac"
}

# module "s3_web" {
#   source        = "terraform-aws-modules/s3-bucket/aws"
#   bucket        = var.configs.bucket_name
#   force_destroy = true
# }

module "cf" {
  source = "terraform-aws-modules/cloudfront/aws"

  aliases = var.configs.associate_domains

  comment             = var.configs.cf_name
  enabled             = true
  default_root_object = var.configs.root_object
  http_version        = "http2and3"
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  wait_for_deployment = true
  web_acl_id          = var.configs.web_acl_arn

  create_origin_access_control = true

  origin_access_control = {
    "${local.origin_id}" = {
      description      = "CloudFront access to S3"
      origin_type      = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }

  # create_origin_access_identity = true

  # origin_access_identities = {
  #   s3_bucket_one = "My awesome CloudFront can access"
  # }

  origin = {
    "${local.origin_id}" = {
      # domain_name           = module.s3_web.s3_bucket_bucket_regional_domain_name
      domain_name           = var.configs.bucket_domain_name
      origin_access_control = "${local.origin_id}"
    }
  }

  default_cache_behavior = merge(
    { target_origin_id = local.origin_id },
    try(var.configs.default_origin.cache_behaviour, {
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD", "OPTIONS"]
      cached_methods         = ["GET", "HEAD"]
      compress               = true
      query_string           = true
    })
  )

  viewer_certificate = {
    acm_certificate_arn            = var.certificate_arn
    cloudfront_default_certificate = false
    minimum_protocol_version       = "TLSv1.2_2019"
    ssl_support_method             = "sni-only"
  }

  tags = merge(var.tags, { Name : "${var.configs.cf_name}" })
}
