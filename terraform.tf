terraform {
  cloud {
    organization = "kmutt-4life"

    workspaces {
      name = "4life-prod"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}
