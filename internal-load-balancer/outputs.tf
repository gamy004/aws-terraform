output "public_alb" {
  value = module.public_alb
}

output "private_alb" {
  value = module.private_alb
}

output "private_nlb" {
  value = module.private_nlb
}

# output "api_endpoints" {
#   value = data.aws_network_interface.api_gateway_endpoints
# }
