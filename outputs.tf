# output "database" {
#   sensitive = true
#   value = module.database.instance
# }

# output "private_ips" {
#     value = module.load_balancers.private_ips
# }

# output "db_configs" {
#   value = local.db_configs
# }

output "service_definitions" {
  value = module.service.service_definitions
}
