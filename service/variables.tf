variable "region" {
  description = "Value of the region for the service"
  type        = string
}

variable "vpc_id" {
  description = "Value of the vpc id for the service"
  type        = string
}

variable "ecr_repositories" {
  description = "Value of the ecr repositories for the service"
  type        = any
  default = {
    "<application>-service-<environment>" = {
      repository_url = "aws_account_id.dkr.ecr.region.amazonaws.com/repositoryName"
    }
  }
}

variable "configs" {
  description = "Value of the configurations for the service"
  type = object({
    cluster_name       = string
    subnet_ids         = list(string)
    security_group_ids = list(string)
    target_group_arns  = list(string)
    service_configs    = any
  })
  default = {
    cluster_name       = "<project>-cluster-<stage>"
    subnet_ids         = []
    security_group_ids = []
    target_group_arns  = []
    service_configs = [{
      service_name             = "<application>-service-<environment>"
      desired_count            = 1    #optional
      enable_autoscaling       = true #optional
      autoscaling_min_capacity = 1    #optional
      autoscaling_max_capacity = 3    #optional
      service_cpu              = 1024 #optional
      service_memory           = 2048 #optional
      task_cpu                 = 512  #optional
      task_memory              = 1024 #optional
      environment_variables    = {}   #optional
      # host_port                = 80   #optional
      # image                     = "<image_url>" #optional
      enable_cloudwatch_logging = true #optional
      tags = {
        Environment = "<environment>"
        Application = "<application>"
      }
    }]
  }
}

variable "tags" {
  description = "Value of the tags for the api gateway"
  type = object({
    Project   = string
    Stage     = string
    Terraform = bool
  })
  default = {
    Project   = ""
    Stage     = ""
    Terraform = true
  }
}
