# ============================================================
# 03 - Gestión de Identidades y Accesos
# Terraform - Módulos 4, 5, 6 y 7
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

variable "cloudtrail_log_group_name" {
  description = "Nombre del CloudWatch Log Group de CloudTrail (para alarma de root)"
  type        = string
  default     = "aws-cloudtrail-logs"
}

variable "alert_email" {
  description = "Email para recibir alertas de seguridad"
  type        = string
  default     = "security-team@empresa.com"
}

# ============================================================
# DATA SOURCES
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================
# MÓDULO 4: Password Policy + Force MFA
# ============================================================

# Password policy fuerte (CIS Benchmark compliant)
resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 24
  hard_expiry                    = false
}

# Policy para forzar MFA en todos los usuarios IAM
resource "aws_iam_policy" "force_mfa" {
  name        = "ForceMFA"
  description = "Deniega acciones si no hay MFA activo, excepto autogestión de MFA"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowManageOwnMFA"
        Effect = "Allow"
        Action = [
          "iam:CreateVirtualMFADevice",
          "iam:DeleteVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:ResyncMFADevice",
          "iam:ListMFADevices",
          "iam:ListVirtualMFADevices",
          "iam:DeactivateMFADevice"
        ]
        Resource = [
          "arn:aws:iam::*:mfa/$${aws:username}",
          "arn:aws:iam::*:user/$${aws:username}"
        ]
      },
      {
        Sid    = "AllowListActions"
        Effect = "Allow"
        Action = [
          "iam:ListUsers",
          "iam:ListVirtualMFADevices",
          "iam:GetAccountPasswordPolicy",
          "iam:GetAccountSummary"
        ]
        Resource = "*"
      },
      {
        Sid       = "DenyAllExceptMFAManagement"
        Effect    = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:ResyncMFADevice",
          "iam:ListMFADevices",
          "iam:ListVirtualMFADevices",
          "iam:ListUsers",
          "iam:GetAccountPasswordPolicy",
          "iam:GetAccountSummary",
          "sts:GetSessionToken",
          "iam:ChangePassword"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
}

# ============================================================
# MÓDULO 5: Alarma por login de Root
# ============================================================

# SNS Topic para alertas de seguridad
resource "aws_sns_topic" "security_alerts" {
  name = "security-alerts"
}

resource "aws_sns_topic_subscription" "security_email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Metric filter: detectar login de root en CloudTrail logs
resource "aws_cloudwatch_log_metric_filter" "root_login" {
  name           = "RootAccountLogin"
  pattern        = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"
  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name      = "RootAccountLoginCount"
    namespace = "SecurityMetrics"
    value     = "1"
  }
}

# Alarma: dispara cuando root hace login
resource "aws_cloudwatch_metric_alarm" "root_login" {
  alarm_name          = "RootAccountLoginAlarm"
  alarm_description   = "ALERTA: Se detectó login de la cuenta Root"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "RootAccountLoginCount"
  namespace           = "SecurityMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.security_alerts.arn]
}

# Metric filter: detectar cambios en IAM policies
resource "aws_cloudwatch_log_metric_filter" "iam_changes" {
  name           = "IAMPolicyChanges"
  pattern        = "{ ($.eventName = CreatePolicy) || ($.eventName = DeletePolicy) || ($.eventName = AttachUserPolicy) || ($.eventName = AttachRolePolicy) || ($.eventName = AttachGroupPolicy) || ($.eventName = DetachUserPolicy) || ($.eventName = DetachRolePolicy) || ($.eventName = DetachGroupPolicy) }"
  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name      = "IAMPolicyChangesCount"
    namespace = "SecurityMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "iam_changes" {
  alarm_name          = "IAMPolicyChangesAlarm"
  alarm_description   = "ALERTA: Se detectaron cambios en políticas IAM"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "IAMPolicyChangesCount"
  namespace           = "SecurityMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.security_alerts.arn]
}

# ============================================================
# MÓDULO 6: Federación (comentado - requiere Organizations)
# ============================================================

# Descomentar cuando tengas Organizations habilitado:
#
# data "aws_ssoadmin_instances" "main" {}
#
# resource "aws_ssoadmin_permission_set" "readonly" {
#   name             = "ReadOnlyAccess"
#   description      = "Acceso de solo lectura"
#   instance_arn     = tolist(data.aws_ssoadmin_instances.main.arns)[0]
#   session_duration = "PT4H"
# }
#
# resource "aws_ssoadmin_managed_policy_attachment" "readonly" {
#   instance_arn       = tolist(data.aws_ssoadmin_instances.main.arns)[0]
#   managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
#   permission_set_arn = aws_ssoadmin_permission_set.readonly.arn
# }

# ============================================================
# MÓDULO 7: IAM Access Analyzer
# ============================================================

# Analyzer de acceso externo (nivel cuenta)
resource "aws_accessanalyzer_analyzer" "external" {
  analyzer_name = "external-access-analyzer"
  type          = "ACCOUNT"

  tags = {
    Environment = "security"
    ManagedBy   = "terraform"
  }
}

# (Opcional) Analyzer de acceso externo (nivel organización)
# resource "aws_accessanalyzer_analyzer" "org_external" {
#   analyzer_name = "org-external-access-analyzer"
#   type          = "ORGANIZATION"
# }

# (Opcional) Analyzer de accesos no utilizados
# resource "aws_accessanalyzer_analyzer" "unused" {
#   analyzer_name = "unused-access-analyzer"
#   type          = "ACCOUNT_UNUSED_ACCESS"
#
#   configuration {
#     unused_access {
#       unused_access_age = 90
#     }
#   }
# }

# ============================================================
# OUTPUTS
# ============================================================

output "password_policy_configured" {
  description = "Password policy configurada"
  value       = true
}

output "force_mfa_policy_arn" {
  description = "ARN de la policy ForceMFA"
  value       = aws_iam_policy.force_mfa.arn
}

output "root_login_alarm_arn" {
  description = "ARN de la alarma de login de root"
  value       = aws_cloudwatch_metric_alarm.root_login.arn
}

output "access_analyzer_arn" {
  description = "ARN del Access Analyzer"
  value       = aws_accessanalyzer_analyzer.external.arn
}

output "sns_topic_arn" {
  description = "ARN del SNS Topic para alertas"
  value       = aws_sns_topic.security_alerts.arn
}
