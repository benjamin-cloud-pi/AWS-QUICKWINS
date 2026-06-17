#!/bin/bash
# ============================================================
# 04 - Detección de Amenazas
# Comandos AWS CLI para Módulos 8, 9 y 10
# ============================================================

# ============================================================
# MÓDULO 8: GuardDuty
# ============================================================

# --- Habilitar GuardDuty ---
echo "=== Habilitando GuardDuty ==="
aws guardduty create-detector --enable \
  --finding-publishing-frequency FIFTEEN_MINUTES

# --- Listar detectors ---
echo "=== Detectors ==="
aws guardduty list-detectors

# --- Obtener ID del detector ---
DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)
echo "Detector ID: $DETECTOR_ID"

# --- Ver estado del detector ---
echo "=== Estado del detector ==="
aws guardduty get-detector --detector-id $DETECTOR_ID \
  --query '{Status:Status,FindingPublishing:FindingPublishingFrequency,Updated:UpdatedAt}'

# --- Generar findings de prueba ---
echo "=== Generando sample findings ==="
aws guardduty create-sample-findings \
  --detector-id $DETECTOR_ID \
  --finding-types '["Recon:EC2/PortProbeUnprotectedPort", "UnauthorizedAccess:IAMUser/MaliciousIPCaller.Custom"]'

# --- Listar findings de severidad HIGH+ ---
echo "=== Findings HIGH+ ==="
aws guardduty list-findings \
  --detector-id $DETECTOR_ID \
  --finding-criteria '{"Criterion": {"severity": {"Gte": 7}}}' \
  --max-results 10

# --- Obtener detalle de findings ---
# FINDING_IDS=$(aws guardduty list-findings --detector-id $DETECTOR_ID --max-results 3 --query 'FindingIds' --output json)
# aws guardduty get-findings --detector-id $DETECTOR_ID --finding-ids "$FINDING_IDS"


# ============================================================
# MÓDULO 9: CloudTrail
# ============================================================

# --- Ver trails existentes ---
echo "=== Trails existentes ==="
aws cloudtrail describe-trails \
  --query 'trailList[].{Name:Name,S3Bucket:S3BucketName,IsOrg:IsOrganizationTrail,MultiRegion:IsMultiRegionTrail}' \
  --output table

# --- Ver estado de un trail ---
# aws cloudtrail get-trail-status --name mi-trail

# --- Buscar eventos de root (últimos 90 días) ---
echo "=== Eventos de root ==="
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=root \
  --max-results 5 \
  --query 'Events[].{Time:EventTime,Event:EventName,Source:EventSource}'

# --- Buscar ConsoleLogin ---
echo "=== Console Logins recientes ==="
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
  --max-results 10 \
  --query 'Events[].{Time:EventTime,User:Username}'

# --- Buscar cambios en Security Groups ---
echo "=== Cambios en Security Groups ==="
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AuthorizeSecurityGroupIngress \
  --max-results 10

# --- Crear trail (si no existe) ---
# aws cloudtrail create-trail \
#   --name main-trail \
#   --s3-bucket-name mi-bucket-cloudtrail-logs \
#   --is-multi-region-trail \
#   --enable-log-file-validation \
#   --include-global-service-events
#
# aws cloudtrail start-logging --name main-trail


# ============================================================
# MÓDULO 10: Billing Alarms
# ============================================================

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# --- Ver budgets existentes ---
echo "=== Budgets existentes ==="
aws budgets describe-budgets \
  --account-id $ACCOUNT_ID \
  --query 'Budgets[].{Name:BudgetName,Limit:BudgetLimit.Amount,Type:BudgetType}' \
  --output table 2>/dev/null || echo "No budgets found"

# --- Crear budget mensual de $100 ---
echo "=== Creando budget ==="
aws budgets create-budget \
  --account-id $ACCOUNT_ID \
  --budget '{
    "BudgetName": "Monthly-Total-100USD",
    "BudgetLimit": {"Amount": "100", "Unit": "USD"},
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }' \
  --notifications-with-subscribers '[
    {
      "Notification": {
        "NotificationType": "ACTUAL",
        "ComparisonOperator": "GREATER_THAN",
        "Threshold": 80,
        "ThresholdType": "PERCENTAGE"
      },
      "Subscribers": [{"SubscriptionType": "EMAIL", "Address": "security-team@empresa.com"}]
    },
    {
      "Notification": {
        "NotificationType": "FORECASTED",
        "ComparisonOperator": "GREATER_THAN",
        "Threshold": 100,
        "ThresholdType": "PERCENTAGE"
      },
      "Subscribers": [{"SubscriptionType": "EMAIL", "Address": "security-team@empresa.com"}]
    }
  ]'

# --- Crear anomaly monitor ---
echo "=== Creando Cost Anomaly Monitor ==="
aws ce create-anomaly-monitor \
  --anomaly-monitor '{
    "MonitorName": "ServiceMonitor",
    "MonitorType": "DIMENSIONAL",
    "MonitorDimension": "SERVICE"
  }'

# --- Ver anomalías detectadas ---
# aws ce get-anomalies \
#   --date-interval '{"StartDate": "2026-06-01", "EndDate": "2026-06-11"}' \
#   --max-results 10
