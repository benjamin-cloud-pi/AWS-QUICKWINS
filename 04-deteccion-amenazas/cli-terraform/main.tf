# ============================================================
# 04 - Detección de Amenazas
# Terraform - Módulos 8, 9 y 10
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
  description = "Email para alertas de seguridad y billing"
  type        = string
  default     = "security-team@empresa.com"
}

variable "monthly_budget_amount" {
  description = "Presupuesto mensual en USD"
  type        = string
  default     = "100"
}

# ============================================================
# DATA SOURCES
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================
# SNS Topic para todas las alertas de detección
# ============================================================

resource "aws_sns_topic" "detection_alerts" {
  name = "detection-security-alerts"
}

resource "aws_sns_topic_subscription" "detection_email" {
  topic_arn = aws_sns_topic.detection_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ============================================================
# MÓDULO 8: GuardDuty
# ============================================================

resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  tags = {
    Environment = "security"
    ManagedBy   = "terraform"
  }
}

# Feature: S3 Protection
resource "aws_guardduty_detector_feature" "s3" {
  detector_id = aws_guardduty_detector.main.id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}

# Feature: EBS Malware Protection
resource "aws_guardduty_detector_feature" "ebs_malware" {
  detector_id = aws_guardduty_detector.main.id
  name        = "EBS_MALWARE_PROTECTION"
  status      = "ENABLED"
}

# EventBridge rule: alertar findings HIGH/CRITICAL de GuardDuty
resource "aws_cloudwatch_event_rule" "guardduty_high" {
  name        = "GuardDutyHighFindings"
  description = "Alerta cuando GuardDuty genera findings de severidad HIGH o CRITICAL"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })
}

resource "aws_cloudwatch_event_target" "guardduty_to_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_high.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.detection_alerts.arn
}

# Permitir EventBridge publicar en SNS
resource "aws_sns_topic_policy" "allow_eventbridge" {
  arn = aws_sns_topic.detection_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowEventBridge"
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.detection_alerts.arn
      }
    ]
  })
}

# ============================================================
# MÓDULO 9: CloudTrail
# ============================================================

# S3 bucket para logs
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = "cloudtrail-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = false

  tags = {
    Environment = "security"
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}

# CloudWatch Log Group para CloudTrail
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "cloudtrail-logs"
  retention_in_days = 365
}

# IAM Role para CloudTrail → CloudWatch
resource "aws_iam_role" "cloudtrail_cloudwatch" {
  name = "CloudTrailToCloudWatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  name = "CloudTrailToCloudWatchPolicy"
  role = aws_iam_role.cloudtrail_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}

# Trail principal
resource "aws_cloudtrail" "main" {
  name                          = "main-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cloudwatch.arn

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]

  tags = {
    Environment = "security"
    ManagedBy   = "terraform"
  }
}

# ============================================================
# MÓDULO 10: Billing Alarms
# ============================================================

# Budget mensual con alertas escalonadas
resource "aws_budgets_budget" "monthly" {
  name         = "Monthly-Total"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_amount
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "ACTUAL"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "ACTUAL"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "ACTUAL"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "FORECASTED"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [var.alert_email]
  }
}

# Cost Anomaly Detection
resource "aws_ce_anomaly_monitor" "service" {
  name              = "ServiceAnomalyMonitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "alerts" {
  name      = "CostAnomalyAlerts"
  frequency = "DAILY"

  monitor_arn_list = [aws_ce_anomaly_monitor.service.arn]

  subscriber {
    type    = "EMAIL"
    address = var.alert_email
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = ["10"]
    }
  }
}

# ============================================================
# OUTPUTS
# ============================================================

output "guardduty_detector_id" {
  description = "ID del detector de GuardDuty"
  value       = aws_guardduty_detector.main.id
}

output "cloudtrail_name" {
  description = "Nombre del trail"
  value       = aws_cloudtrail.main.name
}

output "cloudtrail_s3_bucket" {
  description = "Bucket S3 de logs de CloudTrail"
  value       = aws_s3_bucket.cloudtrail_logs.id
}

output "budget_name" {
  description = "Nombre del budget"
  value       = aws_budgets_budget.monthly.name
}

output "anomaly_monitor_arn" {
  description = "ARN del monitor de anomalías de costos"
  value       = aws_ce_anomaly_monitor.service.arn
}

output "sns_topic_arn" {
  description = "ARN del SNS Topic para alertas de detección"
  value       = aws_sns_topic.detection_alerts.arn
}
