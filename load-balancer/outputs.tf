output "external_alb" {
  value = module.external_lb.external_alb
}

output "public_alb" {
  value = module.internal_lb.public_alb
}

output "private_alb" {
  value = module.internal_lb.private_alb
}

# output "private_ips" {
#   value = module.internal_lb.alb_private_ips
# }
