# variable "region" {
#   description = "Value of the region for the service"
#   type        = string
# }

# variable "vpc_id" {
#   description = "Value of the vpc id for the service"
#   type        = string
# }

variable "configs" {
  description = "Value of the configurations for the authentication"
  type = object({
    user_pool_name           = string
    password_minimum_length  = number
    username_attributes      = list(string)
    required_user_attributes = list(string)
    tags = object({
      Environment = string
    })
  })
  default = {
    user_pool_name           = "<project>-user-pool-<environment>"
    password_minimum_length  = 6
    username_attributes      = ["email"]
    required_user_attributes = ["email"]
    tags = {
      Environment = "<environment>"
    }
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
