output "external_alb_sg" {
  value = aws_security_group.external_alb_sg
}

output "public_alb_sg" {
  value = aws_security_group.public_alb_sg
}

output "private_alb_sg" {
  value = aws_security_group.private_alb_sg
}

output "app_sg" {
  value = aws_security_group.app_sg
}

output "secure_sg" {
  value = module.secure_sg
}
