# Example tfvars — copy to terraform.tfvars (gitignored) or pass via make ENGINEER=

engineer_id        = "demo"
aws_region         = "eu-west-2"
instance_type      = "t3.medium"
enable_auto_stop   = true
monthly_budget_usd = 80
# budget_alert_email = "mentor@example.com"
# Open to the internet so Caddy can complete Let's Encrypt challenges.
# Do NOT copy the documentation CIDR 203.0.113.0/24 into a live sandbox.
# allowed_ingress_cidrs = ["0.0.0.0/0"]
