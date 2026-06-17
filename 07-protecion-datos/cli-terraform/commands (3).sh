#!/bin/bash
# ============================================================
# 07 - Protección de Datos
# Comandos AWS CLI para Módulos 13 y 14
# ============================================================

set -euo pipefail
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# ============================================================
# MÓDULO 13: S3 Block Public Access
# ============================================================

# --- Activar BPA a nivel cuenta ---
echo "=== Activando S3 BPA a nivel cuenta ==="
aws s3control put-public-access-block \
  --account-id "$ACCOUNT_ID" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# --- Verificar BPA a nivel cuenta ---
echo "=== Estado BPA a nivel cuenta ==="
aws s3control get-public-access-block \
  --account-id "$ACCOUNT_ID"

# --- Verificar BPA en un bucket ---
# aws s3api get-public-access-block --bucket mi-bucket

# --- Detectar buckets sin BPA ---
echo "=== Buckets para revisar ==="
for BUCKET in $(aws s3api list-buckets --query 'Buckets[].Name' --output text); do
  BPA=$(aws s3api get-public-access-block --bucket "$BUCKET" 2>/dev/null || echo "NO_BPA")
  if echo "$BPA" | grep -q "NO_BPA"; then
    echo "⚠️  $BUCKET → sin BPA explícito (hereda de cuenta)"
  fi
done

# --- Verificar snapshots públicos ---
echo "=== EBS Snapshots públicos ==="
aws ec2 describe-snapshots --owner-ids self \
  --query 'Snapshots[].SnapshotId' --output text | while read SNAP; do
  PERM=$(aws ec2 describe-snapshot-attribute --snapshot-id "$SNAP" --attribute createVolumePermission \
    --query 'CreateVolumePermissions[?Group==`all`]' --output text 2>/dev/null)
  if [ -n "$PERM" ]; then
    echo "⚠️  $SNAP → PÚBLICO"
  fi
done

# ============================================================
# MÓDULO 14: Amazon Macie
# ============================================================

# --- Habilitar Macie ---
echo "=== Habilitando Macie ==="
aws macie2 enable-macie 2>/dev/null || echo "Macie ya habilitado"

# --- Verificar estado ---
echo "=== Estado de Macie ==="
aws macie2 get-macie-session \
  --query '{Status:status,Created:createdAt}'

# --- Inventario de buckets ---
echo "=== Inventario Macie de buckets ==="
aws macie2 describe-buckets \
  --query 'buckets[].{Name:bucketName,Public:publicAccess.effectivePermission,Encryption:defaultServerSideEncryption.encryptionType}' \
  --output table

# --- Estadísticas de buckets ---
echo "=== Estadísticas ==="
aws macie2 get-bucket-statistics

# --- Findings HIGH ---
echo "=== Findings HIGH ==="
aws macie2 list-findings \
  --finding-criteria '{
    "criterion": {
      "severity.description": {"eq": ["High"]},
      "archived": {"eq": ["false"]}
    }
  }' \
  --max-results 10
