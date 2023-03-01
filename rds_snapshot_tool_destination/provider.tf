terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider with appropriate Region for the destination account.
provider "aws" {
  region = "us-east-1"
}
