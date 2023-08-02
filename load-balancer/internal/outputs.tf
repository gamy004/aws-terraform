output "public_alb" {
  value = module.public_alb
}

output "private_alb" {
  value = module.private_alb
}

# output "alb_private_ips" {
#   value = [for eni in data.aws_network_interface.public_network_interfaces : eni.private_ip]
# }
