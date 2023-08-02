# Internal Load Balancer
module "internal_lb" {
  source = "./internal"

  providers = {
    aws = aws.workload
  }
  
  vpc_id = var.workload_vpc_id
  certificate_arn = var.workload_certificate_arn
  configs = {
    public_alb_name = var.configs.public_alb_name
    private_alb_name = var.configs.private_alb_name
    public_alb_security_group_ids = var.configs.public_alb_security_group_ids
    private_alb_security_group_ids = var.configs.private_alb_security_group_ids
    public_alb_subnet_ids = var.configs.public_alb_subnet_ids
    private_alb_subnet_ids = var.configs.private_alb_subnet_ids
  }
  tags = var.tags
}

# External Load Balancer
module "external_lb" {
  source = "./external"

  providers = {
    aws = aws.network
  }

  depends_on = [ module.internal_lb ]

  vpc_id = var.network_vpc_id
  certificate_arn = var.network_certificate_arn
  configs = {
    name = var.configs.external_alb_name
    target_group_name = var.configs.external_alb_target_group_name
    security_group_ids = var.configs.external_alb_security_group_ids
    subnet_ids = var.configs.external_alb_subnet_ids
    # internal_ips = module.internal_lb.alb_private_ips
    internal_dns_name = module.internal_lb.public_alb.lb_dns_name
  }
  tags = var.tags
}
