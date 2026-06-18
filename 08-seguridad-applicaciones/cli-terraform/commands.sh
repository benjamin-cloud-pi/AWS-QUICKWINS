#!/bin/bash
# ============================================================
# 08 - Seguridad de las Aplicaciones
# Comandos AWS CLI para Módulo 15 (AWS WAF)
# ============================================================

set -euo pipefail
REGION=${AWS_REGION:-us-east-1}

# ============================================================
# LISTAR WEB ACLs
# ============================================================

# --- Web ACLs regionales (ALB, API Gateway) ---
echo "=== Web ACLs REGIONAL ==="
aws wafv2 list-web-acls \
  --scope REGIONAL \
  --region "$REGION" \
  --query 'WebACLs[].{Name:Name,Id:Id,ARN:ARN}' \
  --output table

# --- Web ACLs CloudFront (siempre desde us-east-1) ---
echo "=== Web ACLs CLOUDFRONT ==="
aws wafv2 list-web-acls \
  --scope CLOUDFRONT \
  --region us-east-1 \
  --query 'WebACLs[].{Name:Name,Id:Id,ARN:ARN}' \
  --output table

# ============================================================
# MANAGED RULE GROUPS DISPONIBLES
# ============================================================

# --- Listar AWS Managed Rule Groups ---
echo "=== AWS Managed Rule Groups ==="
aws wafv2 list-available-managed-rule-groups \
  --scope REGIONAL \
  --query 'ManagedRuleGroups[?VendorName==`AWS`].{Name:Name,Description:Description}' \
  --output table

# --- Describir un managed rule group específico ---
# aws wafv2 describe-managed-rule-group \
#   --vendor-name AWS \
#   --name AWSManagedRulesCommonRuleSet \
#   --scope REGIONAL

# ============================================================
# INSPECCIONAR UNA WEB ACL
# ============================================================

# Ejemplo: obtener detalles de la primera Web ACL regional
WEB_ACL_NAME=$(aws wafv2 list-web-acls --scope REGIONAL --query 'WebACLs[0].Name' --output text)
WEB_ACL_ID=$(aws wafv2 list-web-acls --scope REGIONAL --query 'WebACLs[0].Id' --output text)

if [ "$WEB_ACL_NAME" != "None" ] && [ -n "$WEB_ACL_NAME" ]; then
  echo "=== Detalles de Web ACL: $WEB_ACL_NAME ==="
  aws wafv2 get-web-acl \
    --name "$WEB_ACL_NAME" \
    --scope REGIONAL \
    --id "$WEB_ACL_ID" \
    --query '{Name:WebACL.Name,DefaultAction:WebACL.DefaultAction,RuleCount:length(WebACL.Rules)}'
fi

# ============================================================
# RECURSOS ASOCIADOS
# ============================================================

# --- Listar recursos asociados a una Web ACL ---
# aws wafv2 list-resources-for-web-acl \
#   --web-acl-arn "arn:aws:wafv2:us-east-1:123456789012:regional/webacl/xxx/yyy" \
#   --resource-type APPLICATION_LOAD_BALANCER

# --- Tipos de recursos válidos: ---
# APPLICATION_LOAD_BALANCER
# API_GATEWAY
# APPSYNC
# COGNITO_USER_POOL
# APP_RUNNER_SERVICE
# VERIFIED_ACCESS_INSTANCE

# ============================================================
# ASOCIAR / DESASOCIAR
# ============================================================

# --- Asociar Web ACL a un ALB ---
# aws wafv2 associate-web-acl \
#   --web-acl-arn "arn:aws:wafv2:us-east-1:123456789012:regional/webacl/xxx/yyy" \
#   --resource-arn "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/my-alb/xxx"

# --- Desasociar ---
# aws wafv2 disassociate-web-acl \
#   --resource-arn "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/my-alb/xxx"

# ============================================================
# DEBUGGING: SAMPLED REQUESTS
# ============================================================

# --- Ver requests muestreadas (útil para tunear reglas) ---
# aws wafv2 get-sampled-requests \
#   --web-acl-arn "arn:aws:wafv2:us-east-1:123456789012:regional/webacl/xxx/yyy" \
#   --rule-metric-name "aws-managed-common" \
#   --scope REGIONAL \
#   --time-window StartTime=2026-06-17T00:00:00Z,EndTime=2026-06-17T01:00:00Z \
#   --max-items 50

# ============================================================
# LOGGING
# ============================================================

# --- Ver configuración de logging ---
# aws wafv2 get-logging-configuration \
#   --resource-arn "arn:aws:wafv2:us-east-1:123456789012:regional/webacl/xxx/yyy"

# --- Listar configuraciones de logging ---
aws wafv2 list-logging-configurations \
  --scope REGIONAL \
  --query 'LoggingConfigurations[].{ResourceArn:ResourceArn,LogDestination:LogDestinationConfigs[0]}'
