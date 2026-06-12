# ============================================================
# 02 - Aseguramiento de la Seguridad
# Terraform - Módulo 3 (Security Hub / CSPM)
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
  description = "Región donde habilitar Security Hub"
  type        = string
  default     = "us-east-1"
}

variable "enable_fsbp" {
  description = "Habilitar AWS Foundational Security Best Practices"
  type        = bool
  default     = true
}

variable "enable_cis_140" {
  description = "Habilitar CIS AWS Foundations Benchmark v1.4.0"
  type        = bool
  default     = true
}

variable "enable_cis_300" {
  description = "Habilitar CIS AWS Foundations Benchmark v3.0.0"
  type        = bool
  default     = false
}

variable "enable_nist" {
  description = "Habilitar NIST SP 800-53 Rev. 5"
  type        = bool
  default     = false
}

variable "enable_pci_dss" {
  description = "Habilitar PCI DSS v4.0.1 (solo si procesás datos de tarjetas)"
  type        = bool
  default     = false
}

variable "enable_guardduty_integration" {
  description = "Habilitar integración con GuardDuty"
  type        = bool
  default     = true
}

variable "enable_inspector_integration" {
  description = "Habilitar integración con Inspector"
  type        = bool
  default     = false
}

variable "enable_macie_integration" {
  description = "Habilitar integración con Macie"
  type        = bool
  default     = false
}

# ============================================================
# DATA SOURCES
# ============================================================

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ============================================================
# SECURITY HUB - Cuenta
# ============================================================

# Habilitar Security Hub
# enable_default_standards = false para controlar manualmente qué estándares activar
resource "aws_securityhub_account" "main" {
  enable_default_standards  = false
  auto_enable_controls      = true
  control_finding_generator = "SECURITY_CONTROL"
}

# ============================================================
# SECURITY HUB - Estándares
# ============================================================

# AWS Foundational Security Best Practices (FSBP)
# El estándar más recomendado por AWS - cubre los controles más importantes
resource "aws_securityhub_standards_subscription" "fsbp" {
  count         = var.enable_fsbp ? 1 : 0
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
}

# CIS AWS Foundations Benchmark v1.4.0
resource "aws_securityhub_standards_subscription" "cis_140" {
  count         = var.enable_cis_140 ? 1 : 0
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/cis-aws-foundations-benchmark/v/1.4.0"
}

# CIS AWS Foundations Benchmark v3.0.0
resource "aws_securityhub_standards_subscription" "cis_300" {
  count         = var.enable_cis_300 ? 1 : 0
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/cis-aws-foundations-benchmark/v/3.0.0"
}

# NIST SP 800-53 Rev. 5
resource "aws_securityhub_standards_subscription" "nist" {
  count         = var.enable_nist ? 1 : 0
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/nist-800-53/v/5.0.0"
}

# PCI DSS v4.0.1
resource "aws_securityhub_standards_subscription" "pci_dss" {
  count         = var.enable_pci_dss ? 1 : 0
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/pci-dss/v/4.0.1"
}

# ============================================================
# SECURITY HUB - Integraciones con otros servicios
# ============================================================

# Integración con GuardDuty (amenazas)
resource "aws_securityhub_product_subscription" "guardduty" {
  count       = var.enable_guardduty_integration ? 1 : 0
  depends_on  = [aws_securityhub_account.main]
  product_arn = "arn:aws:securityhub:${data.aws_region.current.name}::product/aws/guardduty"
}

# Integración con Inspector (vulnerabilidades)
resource "aws_securityhub_product_subscription" "inspector" {
  count       = var.enable_inspector_integration ? 1 : 0
  depends_on  = [aws_securityhub_account.main]
  product_arn = "arn:aws:securityhub:${data.aws_region.current.name}::product/aws/inspector"
}

# Integración con Macie (datos sensibles)
resource "aws_securityhub_product_subscription" "macie" {
  count       = var.enable_macie_integration ? 1 : 0
  depends_on  = [aws_securityhub_account.main]
  product_arn = "arn:aws:securityhub:${data.aws_region.current.name}::product/aws/macie"
}

# ============================================================
# OUTPUTS
# ============================================================

output "securityhub_account_id" {
  description = "ID de la cuenta con Security Hub habilitado"
  value       = aws_securityhub_account.main.id
}

output "securityhub_arn" {
  description = "ARN del Security Hub"
  value       = aws_securityhub_account.main.arn
}

output "enabled_standards" {
  description = "Estándares habilitados"
  value = compact([
    var.enable_fsbp    ? "AWS Foundational Security Best Practices" : "",
    var.enable_cis_140 ? "CIS AWS Foundations v1.4.0" : "",
    var.enable_cis_300 ? "CIS AWS Foundations v3.0.0" : "",
    var.enable_nist    ? "NIST SP 800-53 Rev. 5" : "",
    var.enable_pci_dss ? "PCI DSS v4.0.1" : "",
  ])
}

output "enabled_integrations" {
  description = "Integraciones habilitadas"
  value = compact([
    var.enable_guardduty_integration ? "GuardDuty" : "",
    var.enable_inspector_integration ? "Inspector" : "",
    var.enable_macie_integration     ? "Macie" : "",
  ])
}

output "region" {
  description = "Región donde está habilitado Security Hub"
  value       = data.aws_region.current.name
}
