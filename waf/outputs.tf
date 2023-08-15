output "backend" {
  value = aws_wafv2_web_acl.backend
}

output "frontend" {
  value = aws_wafv2_web_acl.frontend
}
