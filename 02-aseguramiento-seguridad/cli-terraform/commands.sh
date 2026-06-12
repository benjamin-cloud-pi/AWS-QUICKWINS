#!/bin/bash
# ============================================================
# 02 - Aseguramiento de la Seguridad
# Comandos AWS CLI para Módulo 3 (Security Hub / CSPM)
# ============================================================

# ============================================================
# HABILITAR SECURITY HUB
# ============================================================

# --- Habilitar con estándares por defecto (FSBP + CIS v1.2.0) ---
echo "=== Habilitando Security Hub con estándares por defecto ==="
aws securityhub enable-security-hub \
  --enable-default-standards

# --- Habilitar SIN estándares (para agregarlos manualmente) ---
# aws securityhub enable-security-hub \
#   --no-enable-default-standards

# ============================================================
# VERIFICAR ESTADO
# ============================================================

# --- Ver estado de Security Hub ---
echo "=== Estado de Security Hub ==="
aws securityhub describe-hub

# --- Ver estándares habilitados ---
echo "=== Estándares habilitados ==="
aws securityhub get-enabled-standards \
  --query 'StandardsSubscriptions[].{ARN:StandardsArn,Status:StandardsStatus}' \
  --output table

# --- Listar todos los estándares disponibles ---
echo "=== Estándares disponibles ==="
aws securityhub describe-standards \
  --query 'Standards[].{Name:Name,ARN:StandardsArn}' \
  --output table

# ============================================================
# GESTIONAR ESTÁNDARES
# ============================================================

# --- Habilitar AWS Foundational Security Best Practices ---
echo "=== Habilitando FSBP ==="
aws securityhub batch-enable-standards \
  --standards-subscription-requests \
    '[{"StandardsArn": "arn:aws:securityhub:us-east-1::standards/aws-foundational-security-best-practices/v/1.0.0"}]'

# --- Habilitar CIS AWS Foundations Benchmark v1.4.0 ---
echo "=== Habilitando CIS v1.4.0 ==="
aws securityhub batch-enable-standards \
  --standards-subscription-requests \
    '[{"StandardsArn": "arn:aws:securityhub:us-east-1::standards/cis-aws-foundations-benchmark/v/1.4.0"}]'

# --- (Opcional) Habilitar NIST 800-53 ---
# aws securityhub batch-enable-standards \
#   --standards-subscription-requests \
#     '[{"StandardsArn": "arn:aws:securityhub:us-east-1::standards/nist-800-53/v/5.0.0"}]'

# --- (Opcional) Deshabilitar un estándar ---
# aws securityhub batch-disable-standards \
#   --standards-subscription-arns \
#     '["arn:aws:securityhub:us-east-1:ACCOUNT_ID:subscription/cis-aws-foundations-benchmark/v/1.2.0"]'

# ============================================================
# CONSULTAR FINDINGS
# ============================================================

# --- Findings CRITICAL activos ---
echo "=== Findings CRITICAL ==="
aws securityhub get-findings \
  --filters '{
    "SeverityLabel": [{"Value": "CRITICAL", "Comparison": "EQUALS"}],
    "WorkflowStatus": [{"Value": "NEW", "Comparison": "EQUALS"}],
    "RecordState": [{"Value": "ACTIVE", "Comparison": "EQUALS"}]
  }' \
  --sort-criteria '{"Field": "SeverityNormalized", "SortOrder": "desc"}' \
  --max-items 10 \
  --query 'Findings[].{Title:Title,Severity:Severity.Label,Resource:Resources[0].Id,Account:AwsAccountId}'

# --- Findings HIGH activos ---
echo "=== Findings HIGH ==="
aws securityhub get-findings \
  --filters '{
    "SeverityLabel": [{"Value": "HIGH", "Comparison": "EQUALS"}],
    "WorkflowStatus": [{"Value": "NEW", "Comparison": "EQUALS"}],
    "RecordState": [{"Value": "ACTIVE", "Comparison": "EQUALS"}]
  }' \
  --sort-criteria '{"Field": "SeverityNormalized", "SortOrder": "desc"}' \
  --max-items 10 \
  --query 'Findings[].{Title:Title,Severity:Severity.Label,Resource:Resources[0].Id}'

# --- Contar total de findings activos por severidad ---
echo "=== Conteo de findings activos ==="
for severity in CRITICAL HIGH MEDIUM LOW INFORMATIONAL; do
  count=$(aws securityhub get-findings \
    --filters "{
      \"SeverityLabel\": [{\"Value\": \"$severity\", \"Comparison\": \"EQUALS\"}],
      \"RecordState\": [{\"Value\": \"ACTIVE\", \"Comparison\": \"EQUALS\"}]
    }" \
    --query 'Findings | length(@)' \
    --output text 2>/dev/null)
  echo "  $severity: $count"
done

# --- Findings de un servicio específico (ej: GuardDuty) ---
# aws securityhub get-findings \
#   --filters '{
#     "ProductName": [{"Value": "GuardDuty", "Comparison": "EQUALS"}],
#     "RecordState": [{"Value": "ACTIVE", "Comparison": "EQUALS"}]
#   }' \
#   --max-items 5

# --- Findings FAILED de compliance (controles que no pasan) ---
echo "=== Controles FAILED ==="
aws securityhub get-findings \
  --filters '{
    "ComplianceStatus": [{"Value": "FAILED", "Comparison": "EQUALS"}],
    "RecordState": [{"Value": "ACTIVE", "Comparison": "EQUALS"}]
  }' \
  --max-items 10 \
  --query 'Findings[].{Title:Title,Standard:ProductFields.StandardsArn,Status:Compliance.Status}'

# ============================================================
# INTEGRACIONES
# ============================================================

# --- Ver productos integrados disponibles ---
echo "=== Productos disponibles para integrar ==="
aws securityhub describe-products \
  --query 'Products[?CompanyName==`Amazon`].{Name:ProductName,ARN:ProductArn}' \
  --output table

# --- Habilitar integración con GuardDuty ---
echo "=== Habilitando integración con GuardDuty ==="
aws securityhub enable-import-findings-for-product \
  --product-arn "arn:aws:securityhub:us-east-1::product/aws/guardduty"

# --- Habilitar integración con Inspector ---
# aws securityhub enable-import-findings-for-product \
#   --product-arn "arn:aws:securityhub:us-east-1::product/aws/inspector"

# --- Ver productos habilitados ---
echo "=== Productos habilitados ==="
aws securityhub list-enabled-products-for-import \
  --output table

# ============================================================
# DESHABILITAR (solo si es necesario)
# ============================================================

# --- Deshabilitar Security Hub (⚠️ CUIDADO: elimina todos los findings) ---
# aws securityhub disable-security-hub
