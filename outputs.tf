# output "database" {
#   sensitive = true
#   value = module.database.instance
# }

# output "private_ips" {
#     value = module.load_balancers.private_ips
# }

output "private_alb_https_listener_rules" {
  value = module.internal_lb.private_alb_https_listener_rules
}

output "private_alb_target_groups" {
  value = module.internal_lb.private_alb_target_groups
}

output "private_nlb_target_group" {
  value = module.internal_lb.private_nlb_target_group
}
