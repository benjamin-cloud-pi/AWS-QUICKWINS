#!/bin/bash
# ============================================================
# 01 - Gobierno de la Seguridad
# Comandos AWS CLI para Módulos 1 y 2
# ============================================================

# ============================================================
# MÓDULO 1: Contactos de seguridad
# ============================================================

# --- Verificar contacto de seguridad actual ---
echo "=== Verificando Security Contact actual ==="
aws account get-alternate-contact \
  --alternate-contact-type SECURITY

# --- Configurar contacto de seguridad ---
echo "=== Configurando Security Contact ==="
aws account put-alternate-contact \
  --alternate-contact-type SECURITY \
  --name "Equipo Seguridad" \
  --title "Security Team" \
  --email-address "security-team@empresa.com" \
  --phone-number "+5493512345678"

# --- Verificar que se aplicó ---
echo "=== Verificando que se aplicó correctamente ==="
aws account get-alternate-contact \
  --alternate-contact-type SECURITY

# --- (Opcional) Configurar contacto de billing ---
# aws account put-alternate-contact \
#   --alternate-contact-type BILLING \
#   --name "Equipo FinOps" \
#   --title "FinOps Team" \
#   --email-address "finops@empresa.com" \
#   --phone-number "+5493512345678"

# --- (Opcional) Configurar contacto de operaciones ---
# aws account put-alternate-contact \
#   --alternate-contact-type OPERATIONS \
#   --name "Equipo Operaciones" \
#   --title "Operations Team" \
#   --email-address "ops@empresa.com" \
#   --phone-number "+5493512345678"

# --- (Organizations) Configurar contacto en cuenta miembro ---
# aws account put-alternate-contact \
#   --account-id 123456789012 \
#   --alternate-contact-type SECURITY \
#   --name "Equipo Seguridad" \
#   --title "Security Team" \
#   --email-address "security-team@empresa.com" \
#   --phone-number "+5493512345678"


# ============================================================
# MÓDULO 2: Selección de regiones
# ============================================================

# --- Listar regiones habilitadas ---
echo "=== Regiones habilitadas ==="
aws account list-regions \
  --region-opt-status-contains ENABLED ENABLED_BY_DEFAULT \
  --query 'Regions[].{Region:RegionName,Status:RegionOptStatus}' \
  --output table

# --- Listar SCPs existentes ---
echo "=== SCPs existentes ==="
aws organizations list-policies \
  --filter SERVICE_CONTROL_POLICY \
  --query 'Policies[].{Id:Id,Name:Name}' \
  --output table

# --- Ver detalle de una SCP ---
# aws organizations describe-policy --policy-id p-xxxxxxxxxx

# --- Crear SCP de restricción de regiones ---
echo "=== Creando SCP de restricción de regiones ==="
aws organizations create-policy \
  --name "DenyOutsideAllowedRegions" \
  --description "Bloquea acciones fuera de us-east-1 y sa-east-1" \
  --type SERVICE_CONTROL_POLICY \
  --content '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "DenyAllOutsideAllowedRegions",
        "Effect": "Deny",
        "NotAction": [
          "iam:*",
          "organizations:*",
          "sts:*",
          "cloudfront:*",
          "route53:*",
          "route53domains:*",
          "support:*",
          "budgets:*",
          "ce:*",
          "cur:*",
          "globalaccelerator:*",
          "wafv2:*",
          "waf:*"
        ],
        "Resource": "*",
        "Condition": {
          "StringNotEquals": {
            "aws:RequestedRegion": [
              "us-east-1",
              "sa-east-1"
            ]
          }
        }
      }
    ]
  }'

# --- Adjuntar SCP a una OU ---
# aws organizations attach-policy \
#   --policy-id p-xxxxxxxxxx \
#   --target-id ou-xxxx-xxxxxxxx

# --- Verificar que la SCP está adjuntada ---
# aws organizations list-policies-for-target \
#   --target-id ou-xxxx-xxxxxxxx \
#   --filter SERVICE_CONTROL_POLICY

# --- Verificar bloqueo: intentar describir instancias en región bloqueada ---
echo "=== Test: intentar listar EC2 en ap-southeast-1 (debería fallar) ==="
aws ec2 describe-instances --region ap-southeast-1

# --- Verificar recursos existentes en una región (con Config) ---
# aws configservice get-discovered-resource-counts --region ap-southeast-1
