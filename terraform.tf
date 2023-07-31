terraform {
  cloud {
    organization = "kmutt-4life"
    
    workspaces {
      tags = ["ct4life", "default"]
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