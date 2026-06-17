#!/bin/bash
# ============================================================
# 05 - Gestión de Vulnerabilidades
# Comandos AWS CLI para Módulo 11 (Amazon Inspector)
# ============================================================

# ============================================================
# HABILITAR INSPECTOR
# ============================================================

# --- Habilitar Inspector con todos los resource types ---
echo "=== Habilitando Inspector ==="
aws inspector2 enable \
  --resource-types EC2 ECR LAMBDA LAMBDA_CODE

# --- Verificar estado de habilitación ---
echo "=== Estado de Inspector ==="
aws inspector2 batch-get-account-status \
  --query 'accounts[].{Account:accountId,Status:state.status,EC2:resourceState.ec2.status,ECR:resourceState.ecr.status,Lambda:resourceState.lambda.status}' \
  --output table

# ============================================================
# CONSULTAR FINDINGS
# ============================================================

# --- Findings CRITICAL activos ---
echo "=== Findings CRITICAL ==="
aws inspector2 list-findings \
  --filter-criteria '{
    "findingStatus": [{"comparison": "EQUALS", "value": "ACTIVE"}],
    "severity": [{"comparison": "EQUALS", "value": "CRITICAL"}]
  }' \
  --max-results 10 \
  --query 'findings[].{Title:title,Severity:severity,Resource:resources[0].id,Type:resources[0].type}'

# --- Findings HIGH activos ---
echo "=== Findings HIGH ==="
aws inspector2 list-findings \
  --filter-criteria '{
    "findingStatus": [{"comparison": "EQUALS", "value": "ACTIVE"}],
    "severity": [{"comparison": "EQUALS", "value": "HIGH"}]
  }' \
  --max-results 10 \
  --query 'findings[].{Title:title,Severity:severity,Resource:resources[0].id}'

# --- Findings por tipo de recurso (EC2) ---
echo "=== Findings de EC2 ==="
aws inspector2 list-findings \
  --filter-criteria '{
    "findingStatus": [{"comparison": "EQUALS", "value": "ACTIVE"}],
    "resourceType": [{"comparison": "EQUALS", "value": "AWS_EC2_INSTANCE"}]
  }' \
  --max-results 10

# --- Findings por tipo de recurso (ECR) ---
# aws inspector2 list-findings \
#   --filter-criteria '{
#     "findingStatus": [{"comparison": "EQUALS", "value": "ACTIVE"}],
#     "resourceType": [{"comparison": "EQUALS", "value": "AWS_ECR_CONTAINER_IMAGE"}]
#   }' \
#   --max-results 10

# --- Conteo de findings por severidad ---
echo "=== Conteo por severidad ==="
aws inspector2 list-finding-aggregations \
  --aggregation-type SEVERITY

# ============================================================
# COBERTURA DE ESCANEO
# ============================================================

# --- Ver qué recursos están siendo escaneados ---
echo "=== Cobertura de escaneo ==="
aws inspector2 list-coverage \
  --query 'coveredResources[].{Resource:resourceId,Type:resourceType,Status:scanStatus.statusCode}' \
  --output table

# --- Estadísticas de cobertura ---
echo "=== Estadísticas de cobertura ==="
aws inspector2 list-coverage-statistics \
  --query 'totalCounts'

# ============================================================
# SBOM (Software Bill of Materials)
# ============================================================

# --- Exportar SBOM a S3 ---
# aws inspector2 create-sbom-export \
#   --report-format SPDX_2_3 \
#   --s3-destination '{
#     "bucketName": "mi-bucket-sbom",
#     "keyPrefix": "inspector-sbom/"
#   }'

# ============================================================
# DESHABILITAR (solo si necesario)
# ============================================================

# --- Deshabilitar Inspector ---
# aws inspector2 disable \
#   --resource-types EC2 ECR LAMBDA LAMBDA_CODE
