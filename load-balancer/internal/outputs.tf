output "public_alb" {
  value = module.public_alb
}

output "private_alb" {
  value = module.private_alb
}

output "public_eni_ips" {
  value = {
    subnet_a = data.aws_network_interface.internal_eni_a.private_ip
    subnet_b = data.aws_network_interface.internal_eni_b.private_ip
    subnet_c = data.aws_network_interface.internal_eni_c.private_ip
  }
}
