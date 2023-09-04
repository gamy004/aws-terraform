locals {
  parameters = flatten([
    for config in var.configs : {
      for parameter in config.parameters : "${config.prefix}/${parameter.suffix}/${parameter.name}" => {
        type   = parameter.type
        key_id = parameter.type == "SecureString" ? var.kms_key_id : null
        tier   = "Standard"
        value  = parameter.value
        tags   = merge(var.tags, try(config.tags, {}))
      }
    }
  ])
}

resource "aws_ssm_parameter" "this" {
  for_each = try(merge(local.parameters...), {})

  name   = each.key
  type   = each.value.type
  key_id = each.value.key_id
  tier   = each.value.tier
  value  = each.value.value
  tags   = each.value.tags
}
