variable "STAGE" {
  description = "Value of the stage for the infrastructure"
  type        = string
  default     = "default"
}

variable "instance_name" {
  description = "Value of the Name tag for the EC2 instance"
  type        = string
  default     = "example-instance"
}