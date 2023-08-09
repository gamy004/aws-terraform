variable "region" {
  description = "Value of the region for the service"
  type        = string
}

variable "vpc_id" {
  description = "Value of the vpc id for the service"
  type        = string
}

variable "configs" {
  description = "Value of the configurations for the service"
  type = object({
    cluster_name       = string
    subnet_ids         = list(string)
    security_group_ids = list(string)
    target_group_arns  = list(string)
    service_configs = list(object({
      service_name             = string
      desired_count            = optional(number)
      enable_autoscaling       = optional(bool)
      autoscaling_min_capacity = optional(number)
      autoscaling_max_capacity = optional(number)
      service_cpu              = optional(number)
      service_memory           = optional(number)
      task_cpu                 = optional(number)
      task_memory              = optional(number)
      tags = object({
        Environment = string
        Application = string
      })
    }))
  })
  default = {
    cluster_name       = "<project>-cluster-<stage>"
    subnet_ids         = []
    security_group_ids = []
    target_group_arns  = []
    service_configs = [{
      service_name             = "<application>-service-<environment>"
      desired_count            = 1
      enable_autoscaling       = true
      autoscaling_min_capacity = 1
      autoscaling_max_capacity = 3
      service_cpu              = 1024
      service_memory           = 2048
      task_cpu                 = 512
      task_memory              = 1024
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
