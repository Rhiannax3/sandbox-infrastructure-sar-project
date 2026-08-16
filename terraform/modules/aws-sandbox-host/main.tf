variable "name_prefix" {
  type        = string
  description = "Resource name prefix"
}

variable "engineer_id" {
  type        = string
  description = "Engineer identifier used in SSM paths and hostnames"
}

variable "subnet_id" {
  type        = string
  description = "Public subnet for the EC2 instance"
}

variable "security_group_id" {
  type        = string
  description = "Security group for the EC2 instance"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.medium"
}

variable "app_artifact_bucket" {
  type        = string
  description = "S3 bucket containing the packaged app artifact"
}

variable "app_artifact_key" {
  type        = string
  description = "S3 object key for the app tarball"
  default     = "app/app.zip"
}

variable "keycloak_admin_password" {
  type        = string
  description = "Bootstrap admin password for Keycloak"
  sensitive   = true
}

variable "django_secret_key" {
  type        = string
  description = "Django SECRET_KEY"
  sensitive   = true
}

variable "django_oidc_client_secret" {
  type        = string
  description = "OIDC client secret matching the Keycloak realm export"
  sensitive   = true
}

variable "working_hours_start" {
  type        = string
  description = "Cron expression (UTC) to start the EC2 instance on weekdays"
  default     = "cron(0 7 ? * MON-FRI *)"
}

variable "working_hours_stop" {
  type        = string
  description = "Cron expression (UTC) to stop the EC2 instance on weekdays"
  default     = "cron(0 19 ? * MON-FRI *)"
}

variable "enable_auto_stop" {
  type        = bool
  description = "Enable EventBridge schedules to stop/start EC2 outside working hours"
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_role" "sandbox_host" {
  name = "${var.name_prefix}-sandbox-host"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "sandbox_host" {
  name = "${var.name_prefix}-sandbox-host"
  role = aws_iam_role.sandbox_host.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadAppArtifact"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${var.app_artifact_bucket}",
          "arn:aws:s3:::${var.app_artifact_bucket}/*"
        ]
      },
      {
        Sid      = "ReadSsmParams"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
        Resource = "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/sar-sandbox/${var.engineer_id}/*"
      },
      {
        Sid      = "WriteCloudWatchLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      },
      {
        Sid    = "PublishEngineerLambda"
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration"
        ]
        Resource = "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:${var.name_prefix}-*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.sandbox_host.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "sandbox_host" {
  name = "${var.name_prefix}-sandbox-host"
  role = aws_iam_role.sandbox_host.name
  tags = var.tags
}

resource "aws_eip" "sandbox_host" {
  domain = "vpc"
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eip"
  })
}

locals {
  hostname = "${aws_eip.sandbox_host.public_ip}.nip.io"

  user_data = <<-USERDATA
    #!/bin/bash
    set -euo pipefail
    exec > >(tee /var/log/sar-bootstrap.log) 2>&1

    dnf update -y
    dnf install -y docker jq awscli unzip python3-pip zip tar
    systemctl enable --now docker
    usermod -aG docker ec2-user

    # Docker Compose plugin
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -fsSL "https://github.com/docker/compose/releases/download/v2.39.1/docker-compose-linux-x86_64" \
      -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

    APP_DIR=/opt/sar-sandbox
    mkdir -p "$APP_DIR"
    aws s3 cp "s3://${var.app_artifact_bucket}/${var.app_artifact_key}" /tmp/app.zip
    unzip -o /tmp/app.zip -d "$APP_DIR"

    cat > "$APP_DIR/.env" <<EOF
    HOSTNAME=${local.hostname}
    ENGINEER_ID=${var.engineer_id}
    AWS_REGION=${data.aws_region.current.region}
    KEYCLOAK_ADMIN=admin
    KEYCLOAK_ADMIN_PASSWORD=${var.keycloak_admin_password}
    DJANGO_SECRET_KEY=${var.django_secret_key}
    OIDC_RP_CLIENT_SECRET=${var.django_oidc_client_secret}
    SAR_API_MODE=mock
    SAR_API_AUTH_ENABLED=false
    EOF

    # Build Django image and start the stack on this host (no admin laptop Docker).
    cd "$APP_DIR/compose"
    docker compose --env-file "$APP_DIR/.env" up -d --build

    echo "Bootstrap complete — https://${local.hostname}"
  USERDATA
}

resource "aws_instance" "sandbox_host" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.sandbox_host.name
  user_data              = local.user_data

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-sandbox-host"
  })

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

resource "aws_eip_association" "sandbox_host" {
  instance_id   = aws_instance.sandbox_host.id
  allocation_id = aws_eip.sandbox_host.id
}

# --- Auto stop / start outside working hours ---------------------------------

resource "aws_iam_role" "scheduler" {
  count = var.enable_auto_stop ? 1 : 0
  name  = "${var.name_prefix}-ec2-scheduler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "scheduler" {
  count = var.enable_auto_stop ? 1 : 0
  name  = "${var.name_prefix}-ec2-scheduler"
  role  = aws_iam_role.scheduler[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ec2:StartInstances", "ec2:StopInstances"]
      Resource = aws_instance.sandbox_host.arn
    }]
  })
}

resource "aws_scheduler_schedule" "stop" {
  count                        = var.enable_auto_stop ? 1 : 0
  name                         = "${var.name_prefix}-ec2-stop"
  schedule_expression          = var.working_hours_stop
  schedule_expression_timezone = "UTC"
  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:stopInstances"
    role_arn = aws_iam_role.scheduler[0].arn
    input = jsonencode({
      InstanceIds = [aws_instance.sandbox_host.id]
    })
  }
}

resource "aws_scheduler_schedule" "start" {
  count                        = var.enable_auto_stop ? 1 : 0
  name                         = "${var.name_prefix}-ec2-start"
  schedule_expression          = var.working_hours_start
  schedule_expression_timezone = "UTC"
  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:startInstances"
    role_arn = aws_iam_role.scheduler[0].arn
    input = jsonencode({
      InstanceIds = [aws_instance.sandbox_host.id]
    })
  }
}

output "instance_id" {
  value = aws_instance.sandbox_host.id
}

output "public_ip" {
  value = aws_eip.sandbox_host.public_ip
}

output "hostname" {
  value       = local.hostname
  description = "nip.io hostname for TLS (Caddy + Let's Encrypt)"
}

output "portal_url" {
  value = "https://${local.hostname}"
}

output "keycloak_url" {
  value = "https://${local.hostname}/auth"
}
