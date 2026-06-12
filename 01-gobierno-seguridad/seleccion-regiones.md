# Selecciona regiones permitidas y bloquear el resto

| Campo | Definición |
|-------|------------|
| **Servicio principal** | AWS Organizations / Service Control Policies (SCP) |
| **Prioridad** | Alta |
| **Objetivo** | Definir las regiones donde la organización puede operar y bloquear despliegues fuera de esas regiones |
| **Riesgo mitigado** | Costos o recursos maliciosos en regiones no monitoreadas, incluyendo minería o botnets |

---

## ¿Que es y para que sirve?

AWS tiene mas de 30 regiones en el mundo. Si no restringis donde se pueden crear recursos, alguien (o un atacante con credenciales robadas) podria levantar instancias en EC2 para mina crypto en ap-southeast-1 mientras vos solo monitoreas us-east-1.

Con una **SCP (Service Control Policy)** aplicada desde AWS organizations, podes crear un "deny" para cualquier accion fuera de las regiones que definiste como permitidas. Basicamente es como poner un alambrado del campo pero en una infraestructura

> **En resumen:** bloquear todo lo que no necesitas para que nadie (ni vos por error) pueda crear recursos donde no deberia.

--- 

## ¿Como Funciona?

1. **Documentar** que regiones necesitas (ej: `us-east-1`, `sa-east-1`)
2. **Inventariar** recursos existentes en todas las regiones (para no romper nada)
3. **Crear una SCP** con efecto `deny` para acciones fuera de las regiones permitidas
4. **Exceptuar servicios globales** (IAM, CloudFront, Route 53, Billing, Organizations, STS)
5. **Aplicar la SCP** a la UO o cuenta correspondiente
6. **Testear** intentando crear un recurso en una region bloqueada

### Buenas practicas 

- Documentar regiones permitidas por cliente, ambiente o regulacion
- Inventariar recursos existentes **antes** de aplicar restricciones
- Considerar servicios globales con IAM, CloudFront, Route 53, Billing, Organizations, STS
- Aplicar SCP de deny fuera de regiones permitidas

### Validación mínima
- [ ] Regiones permitidas documentadas
- [ ] No hay workloads en regiones prohibidas
- [ ] SCP aplicada por OU/cuenta
- [ ] Excepciones documentadas

---

## Relacion con otros servicios 

| Se relaciona con | Tipo | ¿Cómo? |
|---|---|---|
| **AWS Organizations** | Directo | Las SCPs se crean y aplican desde Organizations a nivel OU o cuenta |
| **IAM** | Directo | Las SCPs limitan lo que los usuarios/roles IAM pueden hacer, incluso si su policy lo permite. IAM es un servicio global y debe exceptuarse en la SCP |
| **CloudTrail** | Indirecto | CloudTrail debe estar habilitado en las regiones permitidas. Si alguien intenta algo en una región bloqueada, CloudTrail registra el `AccessDenied` |
| **GuardDuty** | Indirecto | GuardDuty solo necesita habilitarse en regiones permitidas, reduciendo costos |
| **Security Hub** | Indirecto | Idem GuardDuty, se habilita solo en regiones permitidas |
| **AWS Config** | Indirecto | Config solo se despliega en regiones permitidas |
| **EC2 / S3 / RDS** | Directo | Son los servicios afectados: no se pueden crear instancias, buckets ni DBs fuera de las regiones permitidas |
| **CloudFront / Route 53** | Excepción | Son servicios globales, deben exceptuarse de la SCP |
| **STS** | Excepción | Necesario para assume role, debe exceptuarse |

### Diagrama

```
AWS Organizations
        │
        ▼
┌─────────────────────┐
│  SCP: Deny Regions  │──── Aplicada a OU / Cuenta
└─────────────────────┘
        │
        │  Bloquea
        ▼
┌───────────────────────────────────────────┐
│  Cualquier acción fuera de:               │
│  us-east-1, sa-east-1 (regiones permitidas)│
│                                           │
│  EXCEPTO servicios globales:              │
│  IAM, CloudFront, Route 53, STS, Billing  │
└───────────────────────────────────────────┘
        │
        │  Resultado
        ▼
┌──────────────────┐     ┌──────────────────┐
│ ✅ us-east-1     │     │ ❌ ap-southeast-1 │
│ ✅ sa-east-1     │     │ ❌ eu-west-1      │
│    (permitidas)  │     │    (bloqueadas)   │
└──────────────────┘     └──────────────────┘
```

---

## Consola

> Ver capturas en [`consola/screenshots.md`](./consola/screenshots.md)

**Ruta en consola:** 

1. AWS Console -> **AWS Organizations** -> **Polices**
2. Click en **Service Control Policies**
3. **Create policy** -> Attach a la OU o cuenta deseada

**Verificar regiones habilitadas:**

1. AWS console -> **Account** -> **AWS Regions**
2. Aca se ven las regiones opt-in (las que hay que habilitar manualmente)

---

> Ver archivos compeltos en [`cli-terraform`](./cli-terrafom/)

### CLI - Listar regiones habilitadas 

```bash
aws account list-regions --region-opt-status-contains ENABLED
ENABLED_BY_DEFAULT
```

### CLI - Listar politicas SCP existentes

```bash
aws organizations describe-policy --policy-id p-xxxxxxx
```

### CLI- Lista recursos en una region especifica (con AWS Config)

```bash
aws configservice get-discovered-resource-counts --region ap-southeast-1
```

### Terraform - SCP de restrincciones de regiones

```hcl
resource "aws_organizations_policy" "deny_outside_allowed_regions" {
  name        = "DenyOutsideAllowedRegions"
  description = "Bloquea acciones fuera de las regiones permitidas"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyAllOutsideAllowedRegions"
        Effect    = "Deny"
        NotAction = [
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
          "waf:*",
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = [
              "us-east-1",
              "sa-east-1"
            ]
          }
        }
      }
    ]
  })
}

# Attach a la OU deseada
resource "aws_organizations_policy_attachment" "deny_regions_attachment" {
  policy_id = aws_organizations_policy.deny_outside_allowed_regions.id
  target_id = "ou-xxxx-xxxxxxxx"  # ID de la OU
}
```

##  Referencias

- [AWS - Service control policy examples](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps_examples.html)
- [Terraform - aws_organizations_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy)
- [GitHub - terraform-aws-organization-policies](https://github.com/aws-samples/terraform-aws-organization-policies)
- [DEV.to - 25+ Production-Ready SCP Examples](https://dev.to/aws-builders/3-aws-service-control-policy-scp-examples-to-secure-your-accounts-14bl)
- [GitHub - SCP with templatefile](https://github.com/etc-org/aws-scp-templatefile)
