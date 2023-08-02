output "public_alb" {
  value = module.public_alb
}

output "private_alb" {
  value = module.private_alb
}

output "alb_private_ips" {
  value = [for private_ip in data.dns_a_record_set.internal_ips.addrs : private_ip]
}
