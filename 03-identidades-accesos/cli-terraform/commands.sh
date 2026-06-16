#!/bin/bash
# ============================================================
# 03 - Gestión de Identidades y Accesos
# Comandos AWS CLI para Módulos 4, 5, 6 y 7
# ============================================================

# ============================================================
# MÓDULO 4: MFA
# ============================================================

# --- Ver dispositivos MFA asignados ---
echo "=== Dispositivos MFA ==="
aws iam list-virtual-mfa-devices \
  --query 'VirtualMFADevices[].{SerialNumber:SerialNumber,User:User.UserName}' \
  --output table

# --- Generar Credential Report ---
echo "=== Generando Credential Report ==="
aws iam generate-credential-report
sleep 5

# --- Descargar Credential Report (verificar MFA) ---
echo "=== Credential Report - MFA status ==="
aws iam get-credential-report \
  --query 'Content' --output text | base64 -d | \
  cut -d',' -f1,4,8 | head -10

# --- Resumen de cuenta (MFA del root) ---
echo "=== Account Summary ==="
aws iam get-account-summary \
  --query '{
    MFAEnabled: AccountMFAEnabled,
    Users: Users,
    MFADevicesInUse: MFADevicesInUse
  }'

# --- Crear MFA virtual para un usuario ---
# aws iam create-virtual-mfa-device \
#   --virtual-mfa-device-name my-mfa-device \
#   --outfile /tmp/QRCode.png \
#   --bootstrap-method QRCodePNG

# --- Habilitar MFA en un usuario ---
# aws iam enable-mfa-device \
#   --user-name mi-usuario \
#   --serial-number arn:aws:iam::123456789012:mfa/my-mfa-device \
#   --authentication-code1 123456 \
#   --authentication-code2 789012

# --- Usar MFA con CLI (get session token) ---
# aws sts get-session-token \
#   --serial-number arn:aws:iam::123456789012:mfa/mi-usuario \
#   --token-code 123456 \
#   --duration-seconds 3600

# --- Ver password policy actual ---
echo "=== Password Policy ==="
aws iam get-account-password-policy 2>/dev/null || echo "No custom password policy set"

# --- Configurar password policy fuerte ---
# aws iam update-account-password-policy \
#   --minimum-password-length 14 \
#   --require-symbols \
#   --require-numbers \
#   --require-uppercase-characters \
#   --require-lowercase-characters \
#   --allow-users-to-change-password \
#   --max-password-age 90 \
#   --password-reuse-prevention 24


# ============================================================
# MÓDULO 5: Protección Root
# ============================================================

# --- Verificar access keys del root ---
echo "=== Root Access Keys (via Credential Report) ==="
aws iam generate-credential-report > /dev/null 2>&1
sleep 3
aws iam get-credential-report \
  --query 'Content' --output text | base64 -d | \
  grep '<root_account>' | cut -d',' -f1,4,9,11,14

# --- Verificar MFA del root ---
echo "=== Root MFA Status ==="
aws iam get-account-summary \
  --query '{AccountMFAEnabled: AccountMFAEnabled}'
# Esperado: AccountMFAEnabled: 1


# ============================================================
# MÓDULO 6: Federación (IAM Identity Center / SSO)
# ============================================================

# --- Configurar perfil SSO en CLI ---
# aws configure sso
# (Te pide: SSO start URL, SSO region, account, role)

# --- Login con SSO ---
# aws sso login --profile mi-perfil-sso

# --- Verificar identidad actual ---
# aws sts get-caller-identity --profile mi-perfil-sso

# --- Listar instancias de Identity Center ---
# aws sso-admin list-instances

# --- Listar Permission Sets ---
# aws sso-admin list-permission-sets \
#   --instance-arn arn:aws:sso:::instance/ssoins-xxxxxxxxxx


# ============================================================
# MÓDULO 7: Limpieza de accesos (IAM Access Analyzer)
# ============================================================

# --- Crear analyzer (tipo ACCOUNT) ---
echo "=== Creando Access Analyzer ==="
aws accessanalyzer create-analyzer \
  --analyzer-name account-external-analyzer \
  --type ACCOUNT

# --- Listar analyzers ---
echo "=== Analyzers existentes ==="
aws accessanalyzer list-analyzers \
  --query 'analyzers[].{Name:name,Type:type,Status:status}' \
  --output table

# --- Listar findings activos ---
echo "=== Findings activos ==="
aws accessanalyzer list-findings-v2 \
  --analyzer-arn arn:aws:access-analyzer:us-east-1:123456789012:analyzer/account-external-analyzer \
  --filter '{"status": {"eq": ["ACTIVE"]}}' \
  --output table

# --- Ver detalle de un finding ---
# aws accessanalyzer get-finding-v2 \
#   --analyzer-arn arn:aws:access-analyzer:us-east-1:123456789012:analyzer/account-external-analyzer \
#   --id finding-id-aqui

# --- Archivar un finding (marcar como aprobado) ---
# aws accessanalyzer update-findings \
#   --analyzer-arn arn:aws:access-analyzer:us-east-1:123456789012:analyzer/account-external-analyzer \
#   --ids '["finding-id-aqui"]' \
#   --status ARCHIVED

# --- Listar recursos analizados ---
# aws accessanalyzer list-analyzed-resources \
#   --analyzer-arn arn:aws:access-analyzer:us-east-1:123456789012:analyzer/account-external-analyzer \
#   --query 'analyzedResources[].{Resource:resourceArn,Type:resourceType}' \
#   --output table
