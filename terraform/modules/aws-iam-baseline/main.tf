variable "name_prefix" {
  type        = string
  description = "Resource name prefix"
}

variable "engineer_id" {
  type        = string
  description = "Engineer identifier"
}

variable "tags" {
  type    = map(string)
  default = {}
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# Permissions boundary — caps what junior IAM roles can ever do
# ---------------------------------------------------------------------------

resource "aws_iam_policy" "junior_boundary" {
  name        = "${var.name_prefix}-junior-boundary"
  description = "Permissions boundary for junior engineer-created roles"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSandboxScopedServices"
        Effect = "Allow"
        Action = [
          "lambda:*",
          "apigateway:*",
          "dynamodb:*",
          "logs:*",
          "cloudwatch:*",
          "xray:*",
          "ssm:GetParameter*",
          "ssm:PutParameter",
          "ssm:DeleteParameter",
          "iam:PassRole",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyEscalation"
        Effect = "Deny"
        Action = [
          "iam:CreateUser",
          "iam:CreateAccessKey",
          "iam:AttachUserPolicy",
          "iam:PutUserPolicy",
          "iam:CreatePolicyVersion",
          "iam:SetDefaultPolicyVersion",
          "iam:DeleteRolePermissionsBoundary",
          "iam:PutRolePermissionsBoundary",
          "organizations:*",
          "account:*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Pre-built Lambda execution role — engineers attach this to their functions
# ---------------------------------------------------------------------------

resource "aws_iam_role" "lambda_execution" {
  name = "${var.name_prefix}-lambda-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  permissions_boundary = aws_iam_policy.junior_boundary.arn
  tags                 = var.tags
}

resource "aws_iam_role_policy" "lambda_execution" {
  name = "${var.name_prefix}-lambda-execution"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.name_prefix}-*"
      },
      {
        Sid    = "DynamoDBSandbox"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:DescribeTable",
          "dynamodb:CreateTable",
          "dynamodb:UpdateTable",
          "dynamodb:DeleteTable",
          "dynamodb:ListTables",
          "dynamodb:DescribeTimeToLive",
          "dynamodb:UpdateTimeToLive"
        ]
        Resource = [
          "arn:aws:dynamodb:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/${var.name_prefix}-*",
          "arn:aws:dynamodb:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/${var.name_prefix}-*/index/*"
        ]
      },
      {
        Sid      = "ReadSsmApiBaseUrl"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:PutParameter"]
        Resource = "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/sar-sandbox/${var.engineer_id}/*"
      },
      {
        Sid      = "XRay"
        Effect   = "Allow"
        Action   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
        Resource = "*"
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# Junior developer IAM policy — attach to their IAM user/role in the sandbox
# ---------------------------------------------------------------------------

resource "aws_iam_policy" "junior_developer" {
  name        = "${var.name_prefix}-junior-developer"
  description = "Least-privilege policy for junior engineers building Project A APIs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaManagement"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:DeleteFunction",
          "lambda:Get*",
          "lambda:List*",
          "lambda:PublishVersion",
          "lambda:CreateAlias",
          "lambda:UpdateAlias",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:InvokeFunction",
          "lambda:TagResource",
          "lambda:UntagResource"
        ]
        Resource = "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:${var.name_prefix}-*"
      },
      {
        Sid      = "ApiGateway"
        Effect   = "Allow"
        Action   = ["apigateway:*"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = data.aws_region.current.region
          }
        }
      },
      {
        Sid    = "DynamoDB"
        Effect = "Allow"
        Action = ["dynamodb:*"]
        Resource = [
          "arn:aws:dynamodb:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/${var.name_prefix}-*",
          "arn:aws:dynamodb:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/${var.name_prefix}-*/index/*"
        ]
      },
      {
        Sid      = "LogsAndMetrics"
        Effect   = "Allow"
        Action   = ["logs:*", "cloudwatch:Get*", "cloudwatch:List*", "cloudwatch:Describe*", "cloudwatch:PutMetricData"]
        Resource = "*"
      },
      {
        Sid      = "PassLambdaRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = aws_iam_role.lambda_execution.arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "lambda.amazonaws.com"
          }
        }
      },
      {
        Sid      = "SsmIntegrationSeam"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:PutParameter", "ssm:DeleteParameter"]
        Resource = "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/sar-sandbox/${var.engineer_id}/*"
      },
      {
        Sid      = "ReadIamRoles"
        Effect   = "Allow"
        Action   = ["iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListRoles"]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# ---------------------------------------------------------------------------
# SSM integration seam — engineers publish their API base URL here
# ---------------------------------------------------------------------------

resource "aws_ssm_parameter" "api_base_url" {
  name        = "/sar-sandbox/${var.engineer_id}/api-base-url"
  description = "Base URL of the engineer-built API Gateway. Portal reads this when SAR_API_MODE=live."
  type        = "String"
  value       = "https://placeholder.invalid"
  overwrite   = true
  tags        = var.tags

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "lambda_role_arn" {
  name  = "/sar-sandbox/${var.engineer_id}/lambda-execution-role-arn"
  type  = "String"
  value = aws_iam_role.lambda_execution.arn
  tags  = var.tags
}

output "lambda_execution_role_arn" {
  value       = aws_iam_role.lambda_execution.arn
  description = "ARN for engineers to attach to their Lambda functions"
}

output "lambda_execution_role_name" {
  value = aws_iam_role.lambda_execution.name
}

output "junior_developer_policy_arn" {
  value       = aws_iam_policy.junior_developer.arn
  description = "Attach this policy to the junior engineer's IAM principal"
}

output "junior_boundary_policy_arn" {
  value = aws_iam_policy.junior_boundary.arn
}

output "api_base_url_parameter_name" {
  value       = aws_ssm_parameter.api_base_url.name
  description = "SSM parameter engineers update with their API Gateway invoke URL"
}
