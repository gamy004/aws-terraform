variable "AWS_DEFAULT_REGION" {
  description = "Value of the default region for the AWS cli"
  type        = string
  default       = "ap-southeast-1"
}

variable "AWS_ACCESS_KEY_ID" {
  description = "Value of the Access Key ID for the AWS cli"
  type        = string
}

variable "AWS_SECRET_ACCESS_KEY" {
  description = "Value of the SECRET Access Key for the AWS cli"
  type        = string
}

variable "instance_name" {
  description = "Value of the Name tag for the EC2 instance"
  type        = string
  default     = "example-instance"
}