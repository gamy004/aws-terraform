terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.network, aws.workload]
    }
  }

  required_version = ">= 1.2.0"
}
