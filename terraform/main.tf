terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Note: To avoid losing state track, you can optionally configure a remote backend here later.
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "us-east-1" # Replace with your preferred AWS region
}

variable "bucket_name" {
  type    = string
  default = "my-unique-github-pipeline-bucket-2026" # S3 names must be globally unique
}

# Creates the S3 Bucket
resource "aws_s3_bucket" "my_bucket" {
  bucket = var.bucket_name

  tags = {
    Environment = "Production"
    ManagedBy   = "GitHub-Actions"
  }
}
