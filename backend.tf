provider "aws" {
  region = "us-east-1" # Change to your preferred region
}

terraform {
  required_version = ">= 1.11.0"
  backend "s3" {
    bucket        = "897722687643-web-tf-state-bucket"
    key           = "usecase7/terraform.tfstate"
    region        = "us-east-1"
    encrypt       = true
    use_lockfile  = true # Enables native S3 state locking
  }
}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
