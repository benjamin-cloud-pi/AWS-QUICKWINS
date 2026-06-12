# ============================================================
# 01 - Gobierno de la Seguridad
# Terraform - Módulos 1 y 2
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
  region = "us-east-1"
}

# ============================================================
# VARIABLES
# ============================================================

variable "security_contact_name" {
  description = "Nombre del contacto de seguridad"
  type        = string
  default     = "Equipo Seguridad"
}

variable "security_contact_email" {
  description = "Email del contacto de seguridad (usar lista de distribución)"
  type        = string
  default     = "security-team@empresa.com"
}

variable "security_contact_phone" {
  description = "Teléfono del contacto de seguridad"
  type        = string
  default     = "+5493512345678"
}

variable "security_contact_title" {
  description = "Título/cargo del contacto de seguridad"
  type        = string
  default     = "Security Team"
}

variable "allowed_regions" {
  description = "Regiones permitidas para desplegar recursos"
  type        = list(string)
  default     = ["us-east-1", "sa-east-1"]
}

variable "target_ou_id" {
  description = "ID de la OU donde aplicar la SCP de regiones"
  type        = string
  default     = "ou-xxxx-xxxxxxxx"  # Reemplazar con tu OU
}

# ============================================================
# MÓDULO 1: Contactos de seguridad
# ============================================================

# Contacto de seguridad
resource "aws_account_alternate_contact" "security" {
  alternate_contact_type = "SECURITY"
  name                   = var.security_contact_name
  title                  = var.security_contact_title
  email_address          = var.security_contact_email
  phone_number           = var.security_contact_phone
}

# (Opcional) Contacto de billing
# resource "aws_account_alternate_contact" "billing" {
#   alternate_contact_type = "BILLING"
#   name                   = "Equipo FinOps"
#   title                  = "FinOps Team"
#   email_address          = "finops@empresa.com"
#   phone_number           = "+5493512345678"
# }

# (Opcional) Contacto de operaciones
# resource "aws_account_alternate_contact" "operations" {
#   alternate_contact_type = "OPERATIONS"
#   name                   = "Equipo Operaciones"
#   title                  = "Operations Team"
#   email_address          = "ops@empresa.com"
#   phone_number           = "+5493512345678"
# }

# ============================================================
# MÓDULO 2: Selección de regiones (SCP)
# ============================================================

# SCP para bloquear acciones fuera de regiones permitidas
resource "aws_organizations_policy" "deny_outside_allowed_regions" {
  name        = "DenyOutsideAllowedRegions"
  description = "Bloquea acciones fuera de las regiones permitidas: ${join(", ", var.allowed_regions)}"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyAllOutsideAllowedRegions"
        Effect = "Deny"
        NotAction = [
          # Servicios globales que deben exceptuarse
          "iam:*",
          "organizations:*",
          "sts:*",
          "cloudfront:*",
          "route53:*",
          "route53domains:*",
          "support:*",
          "budgets:*",
          "ce:*",          # Cost Explorer
          "cur:*",         # Cost and Usage Reports
          "globalaccelerator:*",
          "wafv2:*",
          "waf:*",
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics",
          "tag:*",
          "health:*",
          "trustedadvisor:*"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = var.allowed_regions
          }
        }
      }
    ]
  })
}

# Adjuntar SCP a la OU
resource "aws_organizations_policy_attachment" "deny_regions" {
  policy_id = aws_organizations_policy.deny_outside_allowed_regions.id
  target_id = var.target_ou_id
}

# ============================================================
# OUTPUTS
# ============================================================

output "security_contact_type" {
  description = "Tipo de contacto configurado"
  value       = aws_account_alternate_contact.security.alternate_contact_type
}

output "scp_policy_id" {
  description = "ID de la SCP de restricción de regiones"
  value       = aws_organizations_policy.deny_outside_allowed_regions.id
}

output "scp_policy_arn" {
  description = "ARN de la SCP de restricción de regiones"
  value       = aws_organizations_policy.deny_outside_allowed_regions.arn
}

output "allowed_regions" {
  description = "Regiones permitidas configuradas"
  value       = var.allowed_regions
}
