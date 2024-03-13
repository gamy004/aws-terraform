terraform {
  cloud {
    organization = "kmutt-4life"

    workspaces {
      name = "4life-nonprod"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.2.0"
}
