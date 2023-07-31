terraform {
  cloud {
    organization = "kmutt-4life"
    
    workspaces {
      name = "ct4life-dev"
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