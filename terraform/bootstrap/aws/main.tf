terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.58"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "sar-sandbox"
      ManagedBy = "terraform"
      Purpose   = "remote-state"
    }
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region for the remote state bucket"
  default     = "eu-west-2"
}

variable "state_bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name for Terraform state"
  default     = "sar-sandbox-tfstate"
}

resource "aws_s3_bucket" "tfstate" {
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# State locking uses S3 native lockfiles (backend use_lockfile = true).
# DynamoDB lock tables are no longer required (dynamodb_table is deprecated in Terraform >= 1.11).

output "state_bucket" {
  value       = aws_s3_bucket.tfstate.bucket
  description = "S3 bucket for Terraform state"
}

output "backend_config_snippet" {
  value = <<-EOT
    backend "s3" {
      bucket       = "${aws_s3_bucket.tfstate.bucket}"
      key          = "project-a-aws/terraform.tfstate"
      region       = "${var.aws_region}"
      encrypt      = true
      use_lockfile = true
    }
  EOT
  description = "Paste into the terraform {} block in project-a-aws/main.tf after bootstrap"
}
