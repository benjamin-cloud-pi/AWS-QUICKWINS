#  Descubrimiento de datos sensibles con Amazon Macie

| Campo | Definición |
|-------|------------|
| **Servicio principal** | Amazon Macie |
| **Prioridad** | Alta |
| **Objetivo** | Descubrir automáticamente datos sensibles (PII, credenciales, datos financieros) almacenados en S3 |
| **Riesgo mitigado** | Datos sensibles sin clasificar, sin proteger o en buckets con permisos laxos |

---

## ¿Qué es y para qué sirve?

Amazon Macie es un servicio de **descubrimiento y protección de datos sensibles**
que usa machine learning y coincidencia de patrones para identificar y alertar
sobre datos como:

- **PII**: nombres, emails, DNIs, pasaportes, números de teléfono
- **Datos financieros**: números de tarjetas de crédito, cuentas bancarias
- **Credenciales**: API keys, access keys, tokens, contraseñas en texto plano
- **Datos de salud**: registros médicos (PHI)
- +100 tipos de datos sensibles

### Analogía

Es como tener un **inspector de aduanas** que revisa cada contenedor (bucket S3)
buscando material prohibido (datos sensibles sin proteger). No solo te dice "hay
algo raro", sino que te dice exactamente qué encontró, en qué archivo y de qué tipo.

### Dos modos de operación

| Modo | Cómo funciona | Costo |
|------|---------------|-------|
| **Automated Sensitive Data Discovery** | Muestreo continuo y automático de todos tus buckets | Incluido tras 30 días trial |
| **Discovery Jobs** | Escaneo dirigido: elegís qué buckets, qué tipos de datos, con qué frecuencia | Por GB escaneado |

> **En resumen:** Macie te dice qué datos sensibles tenés y dónde están.
> Sin Macie, no sabés qué estás protegiendo.

---

##  ¿Cómo funciona?

### Flujo básico

```text
1. Habilitás Macie
         │
         ▼
2. Macie auto-inventaría todos los buckets S3
   • Cantidad, tamaño, cifrado, acceso público, sharing
         │
         ▼
3. Automated Discovery (continuo):
   • Muestrea objetos de todos los buckets
   • Clasifica por sensibilidad: alto/medio/bajo
         │
         ▼
4. Discovery Jobs (bajo demanda):
   • Escaneo profundo de buckets específicos
   • Busca tipos de datos específicos (PII, credentials, etc.)
         │
         ▼
5. Genera findings:
   • Tipo de dato sensible encontrado
   • Bucket y objeto específico
   • Cantidad de ocurrencias
   • Severidad
         │
         ▼
6. Findings disponibles en:
   • Console de Macie
   • Security Hub
   • EventBridge → SNS/Lambda
```

### Tipos de findings

| Categoría | Qué detecta | Ejemplo |
|-----------|-------------|---------|
| **SensitiveData:S3Object** | Datos sensibles en objetos S3 | "Se encontraron 45 números de tarjeta de crédito en archivo.csv" |
| **Policy:IAMUser/S3BucketPublic** | Bucket con acceso público | "El bucket tiene ACL pública" |
| **Policy:IAMUser/S3BucketSharedExternally** | Bucket compartido con cuentas externas | "El bucket permite acceso cross-account sin justificación" |

### Buenas prácticas

- Habilitar Macie en la cuenta de seguridad como administrador delegado
- Activar Automated Sensitive Data Discovery
- Crear discovery jobs para buckets de alto riesgo
- Integrar findings con Security Hub
- Alertar findings HIGH/CRITICAL
- Definir proceso de remediación para datos sensibles encontrados

---

##  Relación con otros servicios

| Servicio | Relación |
|---|---|
| **S3** | Macie escanea exclusivamente datos almacenados en buckets S3 |
| **Security Hub** | Envía findings de Macie para visibilidad centralizada |
| **EventBridge** | Reglas que reaccionan a findings (ej: datos sensibles en bucket público → alert + remediar) |
| **Organizations** | Administrador delegado gestiona Macie en todas las cuentas miembro |
| **CloudTrail** | Registra acciones sobre Macie y accesos a objetos S3 |
| **Lambda** | Automatizar remediación (ej: cifrar objeto, mover a bucket seguro, notificar owner) |
| **KMS** | Macie puede escanear objetos cifrados con KMS si tiene permisos sobre la key |
| **S3 BPA** | Complemento: BPA previene acceso público; Macie detecta datos sensibles en cualquier bucket |
| **IAM Access Analyzer** | Complemento: Analyzer detecta acceso externo; Macie detecta contenido sensible |

### Diagrama

```text
┌────────────────────────────────────────────────────────┐
│                   BUCKETS S3                            │
│                                                         │
│  bucket-app  │  bucket-logs  │  bucket-datos-clientes  │
└───────┬──────────────┬──────────────────┬──────────────┘
        │              │                  │
        └──────────────┼──────────────────┘
                       │
                       ▼
         ┌──────────────────────────┐
         │      AMAZON MACIE        │
         │                          │
         │  • Inventario de buckets │
         │  • Automated Discovery   │
         │  • Discovery Jobs        │
         │  • ML + pattern matching │
         └────────────┬─────────────┘
                      │ findings
           ┌──────────┼──────────┐
           ▼          ▼          ▼
     Security Hub  EventBridge  Console
           │          │
           │     ┌────┼────┐
           │     ▼    ▼    ▼
           │    SNS Lambda Jira
           │  (alert)(fix) (ticket)
           ▼
     Dashboard centralizado
```

---

## Consola

> Ver capturas en [`consola/screenshots.md`](./consola/screenshots.md)

### Habilitar Macie

1. AWS Console → buscar **Macie**
2. Click **Get started** → **Enable Macie**

### S3 Buckets Summary

1. Macie → **S3 buckets**
2. Muestra inventario: cantidad, cifrado, acceso público, sensibilidad

### Findings

1. Macie → **Findings**
2. Filtrar por: Severity (High first), Finding type, Bucket name

### Crear Discovery Job

1. Macie → **Jobs** → **Create job**
2. Seleccionar buckets → tipos de datos → frecuencia → nombre → Create

---

##  CLI + Terraform

### CLI - Habilitar Macie

```bash
aws macie2 enable-macie
```

### CLI - Verificar estado

```bash
aws macie2 get-macie-session \
  --query '{Status:status,Created:createdAt,Finding:findingPublishingFrequency}'
```

### CLI - Ver inventario de buckets S3

```bash
aws macie2 describe-buckets \
  --query 'buckets[].{Name:bucketName,Public:publicAccess.effectivePermission,Encryption:defaultServerSideEncryption.encryptionType,Sensitivity:sensitivityScore}' \
  --output table
```

### CLI - Estadísticas de buckets

```bash
aws macie2 get-bucket-statistics
```

### CLI - Listar findings

```bash
aws macie2 list-findings \
  --finding-criteria '{
    "criterion": {
      "severity.description": {"eq": ["High"]},
      "archived": {"eq": ["false"]}
    }
  }' \
  --max-results 10
```

### CLI - Obtener detalle de findings

```bash
# FINDING_IDS=$(aws macie2 list-findings --max-results 5 --query 'findingIds' --output json)
# aws macie2 get-findings --finding-ids "$FINDING_IDS"
```

### CLI - Crear discovery job

```bash
# aws macie2 create-classification-job \
#   --job-type ONE_TIME \
#   --name "scan-datos-clientes" \
#   --s3-job-definition '{
#     "bucketDefinitions": [{
#       "accountId": "123456789012",
#       "buckets": ["bucket-datos-clientes"]
#     }]
#   }'
```

### Terraform

```hcl
# Habilitar Macie
resource "aws_macie2_account" "main" {}

# EventBridge: alertar findings HIGH de Macie
resource "aws_cloudwatch_event_rule" "macie_high" {
  name        = "MacieHighFindings"
  description = "Alerta cuando Macie encuentra datos sensibles (HIGH)"

  event_pattern = jsonencode({
    source      = ["aws.macie"]
    detail-type = ["Macie Finding"]
    detail = {
      severity = {
        description = ["High"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "macie_to_sns" {
  rule      = aws_cloudwatch_event_rule.macie_high.name
  target_id = "SendToSNS"
  arn       = var.sns_topic_arn
}
```

---