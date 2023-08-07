# output "database" {
#   sensitive = true
#   value = module.database.instance
# }

# output "private_ips" {
#     value = module.load_balancers.private_ips
# }

output "private_nlb_dns_name" {
  value = module.internal_lb.private_nlb.lb_dns_name
}
