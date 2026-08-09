variable "name_prefix" {
  type        = string
  description = "Resource name prefix"
}

variable "retention_days" {
  type        = number
  description = "CloudWatch Logs retention in days"
  default     = 14
}

variable "tags" {
  type    = map(string)
  default = {}
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "log_archive" {
  bucket = "${var.name_prefix}-log-archive-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-log-archive"
    Purpose = "Feeds Project B landing zone with operational SAR logs"
  })
}

resource "aws_s3_bucket_versioning" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Placeholder log group — engineers' Lambdas will create /aws/lambda/<name_prefix>-* groups.
# This documents the naming convention and gives a subscription target for mentors.
resource "aws_cloudwatch_log_group" "portal" {
  name              = "/sar-sandbox/${var.name_prefix}/portal"
  retention_in_days = var.retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "lambda_convention" {
  name              = "/aws/lambda/${var.name_prefix}-hello"
  retention_in_days = var.retention_days
  tags              = var.tags

  lifecycle {
    # Engineers may recreate/delete this while iterating on Phase 1
    ignore_changes = [tags]
  }
}

# Export CloudWatch Logs to S3 via a Firehose-free subscription filter is complex;
# instead expose a documented export path and an IAM role for scheduled export.
resource "aws_iam_role" "logs_export" {
  name = "${var.name_prefix}-logs-export"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "logs_export" {
  name = "${var.name_prefix}-logs-export"
  role = aws_iam_role.logs_export.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetBucketAcl", "s3:PutObject"]
        Resource = [
          aws_s3_bucket.log_archive.arn,
          "${aws_s3_bucket.log_archive.arn}/*"
        ]
      }
    ]
  })
}

output "log_archive_bucket_name" {
  value = aws_s3_bucket.log_archive.bucket
}

output "log_archive_bucket_arn" {
  value = aws_s3_bucket.log_archive.arn
}

output "logs_export_role_arn" {
  value       = aws_iam_role.logs_export.arn
  description = "Use with CreateExportTask to push CloudWatch Logs into the archive bucket"
}

output "lambda_log_group_prefix" {
  value       = "/aws/lambda/${var.name_prefix}-"
  description = "Engineers should name Lambda log groups under this prefix"
}
