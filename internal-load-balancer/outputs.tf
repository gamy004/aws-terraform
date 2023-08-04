# output "public_alb" {
#   value = module.public_alb
# }

# output "private_alb" {
#   value = module.private_alb
# }

output "private_alb_https_listener_rules" {
  value = local.private_alb_https_listener_rules
}

output "private_alb_target_groups" {
  value = local.private_alb_target_groups
}
