output "public_alb" {
  value = module.public_alb
}

output "private_alb" {
  value = module.private_alb
}

output "alb_private_ips" {
  value = [
    data.aws_network_interface.network_interface_az_a.private_ip,
    data.aws_network_interface.network_interface_az_b.private_ip,
    data.aws_network_interface.network_interface_az_c.private_ip,
  ]
}