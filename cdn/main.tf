
locals {
  current_account_id = data.aws_caller_identity.current.account_id
}

data "aws_wafv2_ip_set" "outbound" {
  name  = var.configs.waf_ip_set_outbound_name
  scope = "CLOUDFRONT"
}

data "aws_caller_identity" "current" {}

resource "aws_wafv2_web_acl" "cf" {
  lifecycle {
    ignore_changes = [
      rule
    ]
  }
  description = var.configs.waf_name
  name        = var.configs.waf_name
  scope       = "CLOUDFRONT"
  tags        = merge(var.tags, { Name = var.configs.waf_name })

  default_action {
    allow {
    }
  }

  rule {
    name     = "allow-kmutt-network-nat-outbound"
    priority = 0

    action {
      allow {
      }
    }

    statement {

      ip_set_reference_statement {
        arn = "arn:aws:wafv2:us-east-1:${local.current_account_id}:global/ipset/${var.configs.waf_ip_set_outbound_name}/${data.aws_wafv2_ip_set.outbound.id}"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "allow-kmutt-network-nat-outbound"
      sampled_requests_enabled   = true
    }
  }
  rule {
    name     = "AWS-AWSManagedRulesAdminProtectionRuleSet"
    priority = 1

    override_action {

      none {}
    }

    statement {

      managed_rule_group_statement {
        name        = "AWSManagedRulesAdminProtectionRuleSet"
        vendor_name = "AWS"

        rule_action_override {
          action_to_use {
            count {}
          }

          name = "AdminProtection_URIPATH"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesAdminProtectionRuleSet"
      sampled_requests_enabled   = true
    }
  }
  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 2

    override_action {

      none {}
    }

    statement {

      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesAmazonIpReputationList"
      sampled_requests_enabled   = true
    }
  }
  rule {
    name     = "AWS-AWSManagedRulesAnonymousIpList"
    priority = 3

    override_action {

      none {}
    }

    statement {

      managed_rule_group_statement {
        name        = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesAnonymousIpList"
      sampled_requests_enabled   = true
    }
  }
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 4

    override_action {

      none {}
    }

    statement {

      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        rule_action_override {
          action_to_use {
            count {}
          }

          name = "CrossSiteScripting_BODY"
        }

        rule_action_override {
          action_to_use {
            count {}
          }

          name = "GenericLFI_BODY"
        }

        rule_action_override {
          action_to_use {
            count {}
          }

          name = "GenericRFI_BODY"
        }

        rule_action_override {
          action_to_use {
            count {}
          }

          name = "SizeRestrictions_BODY"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 5

    override_action {

      none {}
    }

    statement {

      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }
  rule {
    name     = "AWS-AWSManagedRulesLinuxRuleSet"
    priority = 6

    override_action {

      none {}
    }

    statement {

      managed_rule_group_statement {
        name        = "AWSManagedRulesLinuxRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesLinuxRuleSet"
      sampled_requests_enabled   = true
    }
  }
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 7

    override_action {

      none {}
    }

    statement {

      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesSQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.configs.waf_name
    sampled_requests_enabled   = true
  }
}

module "cf" {
  source = "terraform-aws-modules/cloudfront/aws"

  aliases = var.configs.associate_domains

  comment = var.configs.cf_name
  enabled = true
  # default_root_object = "index.html"
  http_version        = "http2and3"
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  wait_for_deployment = true
  web_acl_id          = aws_wafv2_web_acl.cf.arn

  # create_origin_access_identity = true
  # origin_access_identities = {
  #   s3_bucket_one = "My awesome CloudFront can access"
  # }

  create_origin_access_identity = false

  origin_access_identities = {}

  origin = merge(
    {
      "${var.configs.default_origin.name}" = {
        domain_name          = var.configs.default_origin.domain_name
        custom_origin_config = try(var.configs.default_origin.custom_origin_config, {})
      }
    },
    {
      for origin_configs in var.configs.non_default_origins : origin_configs.name => {
        domain_name          = origin_configs.domain_name
        custom_origin_config = try(origin_configs.custom_origin_config, {})
      }
    }
  )
  # {
  # "${var.origin_id}" = {
  #   domain_name = var.origin_domain_name
  #   custom_origin_config = {
  #     http_port                = 80
  #     https_port               = 443
  #     origin_keepalive_timeout = 5
  #     origin_protocol_policy   = "https-only"
  #     origin_read_timeout      = 30
  #     origin_ssl_protocols = [
  #       "SSLv3",
  #       "TLSv1",
  #     ]
  #   }
  # }

  # s3_one = {
  #   domain_name = "my-s3-bycket.s3.amazonaws.com"
  #   s3_origin_config = {
  #     origin_access_identity = "s3_bucket_one"
  #   }
  # }
  # }

  default_cache_behavior = merge(
    { target_origin_id = var.configs.default_origin.name },
    try(var.configs.default_origin.cache_behaviour, {})
  )
  # {
  #   allowed_methods         = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
  #   cached_methods          = ["GET", "HEAD"]
  #   compress                = true
  #   default_ttl             = 86400
  #   max_ttl                 = 31536000
  #   min_ttl                 = 0
  #   smooth_streaming        = false
  #   target_origin_id        = var.configs.default_origin.name
  #   trusted_key_groups      = []
  #   trusted_signers         = []
  #   viewer_protocol_policy  = "redirect-to-https"
  #   headers                 = ["*"]
  #   query_string            = true
  #   query_string_cache_keys = []
  #   cookies_forward         = "all"
  # }

  ordered_cache_behavior = [
    for origin_name, origin_configs in var.configs.non_default_origins : merge(
      { target_origin_id = origin_name },
      try(origin_configs.cache_behaviour, {})
    )
  ]
  # ordered_cache_behavior = [
  #   {
  #     path_pattern           = "*"
  #     target_origin_id       = "s3_one"
  #     viewer_protocol_policy = "redirect-to-https"

  #     allowed_methods = ["GET", "HEAD", "OPTIONS"]
  #     cached_methods  = ["GET", "HEAD"]
  #     compress        = true
  #     query_string    = true
  #   }
  # ]

  viewer_certificate = {
    acm_certificate_arn            = var.certificate_arn
    cloudfront_default_certificate = false
    minimum_protocol_version       = "TLSv1.2_2019"
    ssl_support_method             = "sni-only"
  }

  tags = merge(var.tags, { Name : "${var.configs.cf_name}" })
}
