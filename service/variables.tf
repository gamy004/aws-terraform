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
    cluster_name = string
    service_configs = list(object({
      service_name = string
      tags = object({
        Environment = string
        Application = string
      })
    }))
  })
  default = {
    cluster_name = "<project>-cluster-<stage>"
    service_configs = [{
      service_name = "<application>-service-<environment>"
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
