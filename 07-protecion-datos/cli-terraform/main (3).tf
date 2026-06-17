# ============================================================
# 07 - Protección de Datos
# Terraform - Módulos 13 y 14
# ============================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = var.region }

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "alert_email" {
  type    = string
  default = "security-team@empresa.com"
}

data "aws_caller_identity" "current" {}

# ============================================================
# MÓDULO 13: S3 Block Public Access (cuenta)
# ============================================================

resource "aws_s3_account_public_access_block" "account" {
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# ============================================================
# MÓDULO 14: Amazon Macie
# ============================================================

resource "aws_macie2_account" "main" {}

# ============================================================
# SNS Topic para alertas de protección de datos
# ============================================================

resource "aws_sns_topic" "data_protection_alerts" {
  name = "data-protection-alerts"
}

resource "aws_sns_topic_subscription" "data_protection_email" {
  topic_arn = aws_sns_topic.data_protection_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# EventBridge: Macie HIGH findings → SNS
resource "aws_cloudwatch_event_rule" "macie_high" {
  name        = "MacieHighFindings"
  description = "Alerta cuando Macie encuentra datos sensibles HIGH"

  event_pattern = jsonencode({
    source      = ["aws.macie"]
    detail-type = ["Macie Finding"]
    detail = {
      severity = {
        description = ["High"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "macie_to_sns" {
  rule      = aws_cloudwatch_event_rule.macie_high.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.data_protection_alerts.arn
}

# Permitir EventBridge publicar en SNS
resource "aws_sns_topic_policy" "allow_eventbridge" {
  arn = aws_sns_topic.data_protection_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowEventBridge"
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "SNS:Publish"
      Resource  = aws_sns_topic.data_protection_alerts.arn
    }]
  })
}

# ============================================================
# OUTPUTS
# ============================================================

output "s3_bpa_enabled" {
  value = "Las 4 configuraciones de BPA están en TRUE a nivel cuenta"
}

output "macie_status" {
  value = "Macie habilitado"
}

output "sns_topic_arn" {
  value = aws_sns_topic.data_protection_alerts.arn
}
