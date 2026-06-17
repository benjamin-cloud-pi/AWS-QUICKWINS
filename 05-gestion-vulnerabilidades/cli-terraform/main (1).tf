# ============================================================
# 05 - Gestión de Vulnerabilidades
# Terraform - Módulo 11 (Amazon Inspector)
# ============================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ============================================================
# VARIABLES
# ============================================================

variable "region" {
  description = "Región de despliegue"
  type        = string
  default     = "us-east-1"
}

variable "alert_email" {
  description = "Email para alertas de vulnerabilidades"
  type        = string
  default     = "security-team@empresa.com"
}

variable "enable_ec2_scanning" {
  description = "Habilitar escaneo de EC2"
  type        = bool
  default     = true
}

variable "enable_ecr_scanning" {
  description = "Habilitar escaneo de ECR"
  type        = bool
  default     = true
}

variable "enable_lambda_scanning" {
  description = "Habilitar escaneo de Lambda"
  type        = bool
  default     = true
}

variable "enable_lambda_code_scanning" {
  description = "Habilitar escaneo de código Lambda"
  type        = bool
  default     = true
}

# ============================================================
# DATA SOURCES
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================
# INSPECTOR v2 - Habilitación
# ============================================================

locals {
  resource_types = compact([
    var.enable_ec2_scanning         ? "EC2" : "",
    var.enable_ecr_scanning         ? "ECR" : "",
    var.enable_lambda_scanning      ? "LAMBDA" : "",
    var.enable_lambda_code_scanning ? "LAMBDA_CODE" : "",
  ])
}

resource "aws_inspector2_enabler" "main" {
  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = local.resource_types
}

# ============================================================
# SNS Topic para alertas de vulnerabilidades
# ============================================================

resource "aws_sns_topic" "vulnerability_alerts" {
  name = "vulnerability-alerts"
}

resource "aws_sns_topic_subscription" "vulnerability_email" {
  topic_arn = aws_sns_topic.vulnerability_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ============================================================
# EventBridge: alertar findings CRITICAL de Inspector
# ============================================================

resource "aws_cloudwatch_event_rule" "inspector_critical" {
  name        = "InspectorCriticalFindings"
  description = "Alerta cuando Inspector encuentra vulnerabilidades CRITICAL"

  event_pattern = jsonencode({
    source      = ["aws.inspector2"]
    detail-type = ["Inspector2 Finding"]
    detail = {
      severity = ["CRITICAL"]
    }
  })
}

resource "aws_cloudwatch_event_target" "inspector_to_sns" {
  rule      = aws_cloudwatch_event_rule.inspector_critical.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.vulnerability_alerts.arn
}

# EventBridge rule para findings HIGH
resource "aws_cloudwatch_event_rule" "inspector_high" {
  name        = "InspectorHighFindings"
  description = "Alerta cuando Inspector encuentra vulnerabilidades HIGH"

  event_pattern = jsonencode({
    source      = ["aws.inspector2"]
    detail-type = ["Inspector2 Finding"]
    detail = {
      severity = ["HIGH"]
    }
  })
}

resource "aws_cloudwatch_event_target" "inspector_high_to_sns" {
  rule      = aws_cloudwatch_event_rule.inspector_high.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.vulnerability_alerts.arn
}

# Permitir EventBridge publicar en SNS
resource "aws_sns_topic_policy" "allow_eventbridge" {
  arn = aws_sns_topic.vulnerability_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowEventBridge"
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.vulnerability_alerts.arn
      }
    ]
  })
}

# ============================================================
# (Opcional) IAM Role para EC2 con SSM
# Necesario para que Inspector pueda escanear las instancias
# ============================================================

resource "aws_iam_role" "ec2_ssm" {
  name = "EC2-SSM-ManagedInstance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "EC2-SSM-ManagedInstance"
  role = aws_iam_role.ec2_ssm.name
}

# ============================================================
# OUTPUTS
# ============================================================

output "inspector_enabled_resource_types" {
  description = "Resource types habilitados en Inspector"
  value       = local.resource_types
}

output "sns_topic_arn" {
  description = "ARN del SNS Topic para alertas de vulnerabilidades"
  value       = aws_sns_topic.vulnerability_alerts.arn
}

output "ec2_ssm_instance_profile" {
  description = "Instance profile para EC2 con SSM (requerido para Inspector)"
  value       = aws_iam_instance_profile.ec2_ssm.name
}
