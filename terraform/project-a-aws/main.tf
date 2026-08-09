terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.58"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Uncomment after running `make bootstrap-aws` and pasting the output snippet:
  # backend "s3" {
  #   bucket         = "sar-sandbox-tfstate"
  #   key            = "project-a-aws/terraform.tfstate"
  #   region         = "eu-west-2"
  #   dynamodb_table = "sar-sandbox-tfstate-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

variable "engineer_id" {
  type        = string
  description = "Short identifier for the junior engineer (used in names and tags)"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,20}$", var.engineer_id))
    error_message = "engineer_id must be 2-20 chars of lowercase alphanumeric and hyphens."
  }
}

variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "allowed_ingress_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the sandbox host"
  default     = ["0.0.0.0/0"]
}

variable "enable_auto_stop" {
  type    = bool
  default = true
}

variable "monthly_budget_usd" {
  type        = number
  description = "AWS Budgets alert threshold for this engineer sandbox"
  default     = 80
}

variable "budget_alert_email" {
  type        = string
  description = "Email for budget alerts (empty to skip)"
  default     = ""
}

locals {
  name_prefix = "sar-${var.engineer_id}"

  common_tags = {
    Project    = "sar-sandbox"
    ManagedBy  = "terraform"
    Engineer   = var.engineer_id
    Programme  = "junior-de-sandbox"
    CostCenter = "training"
  }
}

resource "random_password" "keycloak_admin" {
  length  = 24
  special = false
}

resource "random_password" "django_secret" {
  length  = 50
  special = true
}

resource "random_password" "oidc_client_secret" {
  length  = 32
  special = false
}

# ---------------------------------------------------------------------------
# App artifact bucket + upload
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "artifacts" {
  bucket = "${local.name_prefix}-artifacts-${data.aws_caller_identity.current.account_id}"
  tags   = local.common_tags
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "app_artifact" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "app/app.tar.gz"
  source = "/tmp/sar-app-build/app.tar.gz"
  etag   = fileexists("/tmp/sar-app-build/app.tar.gz") ? filemd5("/tmp/sar-app-build/app.tar.gz") : null

  lifecycle {
    # Allow apply before first package-app; cloud-init will fail until artifact exists
    ignore_changes = [etag]
  }
}

# ---------------------------------------------------------------------------
# Modules
# ---------------------------------------------------------------------------

module "network" {
  source = "../modules/aws-network"

  name_prefix           = local.name_prefix
  allowed_ingress_cidrs = var.allowed_ingress_cidrs
  tags                  = local.common_tags
}

module "iam" {
  source = "../modules/aws-iam-baseline"

  name_prefix = local.name_prefix
  engineer_id = var.engineer_id
  tags        = local.common_tags
}

module "log_archive" {
  source = "../modules/aws-log-archive"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

module "sandbox_host" {
  source = "../modules/aws-sandbox-host"

  name_prefix               = local.name_prefix
  engineer_id               = var.engineer_id
  subnet_id                 = module.network.public_subnet_id
  security_group_id         = module.network.sandbox_host_security_group_id
  instance_type             = var.instance_type
  app_artifact_bucket       = aws_s3_bucket.artifacts.bucket
  app_artifact_key          = aws_s3_object.app_artifact.key
  keycloak_admin_password   = random_password.keycloak_admin.result
  django_secret_key         = random_password.django_secret.result
  django_oidc_client_secret = random_password.oidc_client_secret.result
  enable_auto_stop          = var.enable_auto_stop
  tags                      = local.common_tags

  depends_on = [aws_s3_object.app_artifact]
}

# Store secrets in SSM for operators / redeploy scripts
resource "aws_ssm_parameter" "keycloak_admin_password" {
  name  = "/sar-sandbox/${var.engineer_id}/keycloak-admin-password"
  type  = "SecureString"
  value = random_password.keycloak_admin.result
  tags  = local.common_tags
}

resource "aws_ssm_parameter" "oidc_client_secret" {
  name  = "/sar-sandbox/${var.engineer_id}/oidc-client-secret"
  type  = "SecureString"
  value = random_password.oidc_client_secret.result
  tags  = local.common_tags
}

# ---------------------------------------------------------------------------
# Cost guardrail — AWS Budgets
# ---------------------------------------------------------------------------

resource "aws_budgets_budget" "engineer" {
  count = var.budget_alert_email != "" ? 1 : 0

  name         = "${local.name_prefix}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Engineer$$${var.engineer_id}"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_alert_email]
  }
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "portal_url" {
  value = module.sandbox_host.portal_url
}

output "keycloak_url" {
  value = module.sandbox_host.keycloak_url
}

output "keycloak_admin_username" {
  value = "admin"
}

output "keycloak_admin_password_ssm" {
  value = aws_ssm_parameter.keycloak_admin_password.name
}

output "lambda_execution_role_arn" {
  value = module.iam.lambda_execution_role_arn
}

output "junior_developer_policy_arn" {
  value = module.iam.junior_developer_policy_arn
}

output "api_base_url_parameter" {
  value       = module.iam.api_base_url_parameter_name
  description = "After Phase 1, put your API Gateway invoke URL here"
}

output "log_archive_bucket" {
  value = module.log_archive.log_archive_bucket_name
}

output "hostname" {
  value = module.sandbox_host.hostname
}

output "instance_id" {
  value = module.sandbox_host.instance_id
}
