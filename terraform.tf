terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.2.0"
  cloud {
    organization = "epsilon-terraform"

    workspaces {
      name = "public-amazon-linux-instance"
    }
  }
}


