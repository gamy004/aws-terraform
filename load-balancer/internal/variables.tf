variable "vpc_id" {
  description = "Value of the vpc id for the load balancer"
  type        = string
}

variable "certificate_arn" {
  description = "Value of the certificate arn for the load balancer"
  type        = string
}

variable "configs" {
  description = "Value of the configurations for the load balancer"
  type = object({
    public_alb_name = string
    private_alb_name = string
    public_alb_security_group_ids = list(string)
    private_alb_security_group_ids = list(string)
    public_alb_subnet_ids = list(string)
    private_alb_subnet_ids = list(string)
  })
  default = {
    public_alb_name = "<project>-alb-<stage>"
    private_alb_name = "<project>-nonexpose-alb-<stage>"
    public_alb_security_group_ids = []
    private_alb_security_group_ids = []
    public_alb_subnet_ids = []
    private_alb_subnet_ids = []
  }
}

variable "tags" {
  description = "Value of the tags for the load balancer"
  type        = object({
    Project        = string
    Environment = string
    Terraform   = bool
  })
  default = {
    Project        = ""
    Environment = ""
    Terraform   = true
  }
}