# ============================================================
# 08 - Seguridad de las Aplicaciones
# Terraform - Módulo 15 (AWS WAF v2)
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

variable "web_acl_name" {
  description = "Nombre del Web ACL"
  type        = string
  default     = "production-web-acl"
}

variable "scope" {
  description = "Scope del Web ACL: REGIONAL (ALB/API GW) o CLOUDFRONT"
  type        = string
  default     = "REGIONAL"
}

variable "rate_limit" {
  description = "Límite de requests por IP en ventana de 5 minutos"
  type        = number
  default     = 2000
}

variable "log_retention_days" {
  description = "Días de retención de logs WAF en CloudWatch"
  type        = number
  default     = 90
}

# ============================================================
# WEB ACL con baseline OWASP Top 10
# ============================================================

resource "aws_wafv2_web_acl" "main" {
  name        = var.web_acl_name
  description = "WAF baseline con managed rules para OWASP Top 10"
  scope       = var.scope

  default_action {
    allow {}
  }

  # =========================================================
  # Rule 1: Rate Limit (custom)
  # =========================================================
  rule {
    name     = "rate-limit-per-ip"
    priority = 10

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # =========================================================
  # Rule 2: AWS IP Reputation List
  # =========================================================
  rule {
    name     = "aws-ip-reputation-list"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  # =========================================================
  # Rule 3: Common Rule Set (OWASP Top 10 general)
  # =========================================================
  rule {
    name     = "aws-common-rule-set"
    priority = 30

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-common-rule-set"
      sampled_requests_enabled   = true
    }
  }

  # =========================================================
  # Rule 4: SQL Injection
  # =========================================================
  rule {
    name     = "aws-sqli"
    priority = 40

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-sqli"
      sampled_requests_enabled   = true
    }
  }

  # =========================================================
  # Rule 5: Known Bad Inputs (exploits conocidos, log4j, etc.)
  # =========================================================
  rule {
    name     = "aws-known-bad-inputs"
    priority = 50

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # =========================================================
  # Rule 6: Admin Protection
  # =========================================================
  rule {
    name     = "aws-admin-protection"
    priority = 60

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAdminProtectionRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-admin-protection"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.web_acl_name
    sampled_requests_enabled   = true
  }

  tags = {
    Name      = var.web_acl_name
    ManagedBy = "terraform"
  }
}

# ============================================================
# LOGGING - CloudWatch Logs
# ============================================================

resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.web_acl_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  resource_arn            = aws_wafv2_web_acl.main.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
}

# ============================================================
# ASOCIACIÓN A ALB (ejemplo - descomentar y pasar ARN real)
# ============================================================

# variable "alb_arn" {
#   description = "ARN del ALB a proteger"
#   type        = string
# }
#
# resource "aws_wafv2_web_acl_association" "alb" {
#   resource_arn = var.alb_arn
#   web_acl_arn  = aws_wafv2_web_acl.main.arn
# }

# ============================================================
# CLOUDWATCH ALARMS - Alertar bloqueos masivos
# ============================================================

resource "aws_cloudwatch_metric_alarm" "high_blocked_requests" {
  alarm_name          = "WAF-HighBlockedRequests-${var.web_acl_name}"
  alarm_description   = "Alerta cuando WAF bloquea > 1000 requests en 5 min"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = 1000
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = var.web_acl_name
    Region = var.region
    Rule   = "ALL"
  }
}

# ============================================================
# OUTPUTS
# ============================================================

output "web_acl_arn" {
  description = "ARN del Web ACL"
  value       = aws_wafv2_web_acl.main.arn
}

output "web_acl_id" {
  description = "ID del Web ACL"
  value       = aws_wafv2_web_acl.main.id
}

output "log_group_name" {
  description = "Nombre del Log Group de WAF"
  value       = aws_cloudwatch_log_group.waf.name
}

output "managed_rules_enabled" {
  description = "Managed Rule Groups habilitados"
  value = [
    "AWSManagedRulesAmazonIpReputationList",
    "AWSManagedRulesCommonRuleSet",
    "AWSManagedRulesSQLiRuleSet",
    "AWSManagedRulesKnownBadInputsRuleSet",
    "AWSManagedRulesAdminProtectionRuleSet",
  ]
}
