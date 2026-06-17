#  Gestión de Vulnerabilidades

## Descripción

No alcanza con detectar amenazas activas (GuardDuty): también necesitás saber si tus
workloads **tienen debilidades conocidas** que un atacante puede explotar. Amazon Inspector
escanea continuamente tus EC2, contenedores ECR y funciones Lambda en busca de
**vulnerabilidades de software (CVEs)** y configuraciones inseguras.

Se trabaja **1 QuickWin**:

| # | QuickWin | Servicio principal | Prioridad |
|---|----------|-------------------|-----------| 
| 11 | [Escaneo continuo de vulnerabilidades](./inspector.md) | Amazon Inspector | Alta |

## ¿Por qué importa?

```
Sin Inspector:                        Con Inspector:

  CVE crítico publicado                CVE crítico publicado
       │                                    │
       ▼                                    ▼
  Tus EC2/containers                   Inspector re-escanea automáticamente
  siguen vulnerables                        │
       │                                    ▼
       ▼                                 Finding CRITICAL:
  Atacante explota la vuln               "EC2 i-abc tiene CVE-2025-xxxx"
       │                                    │
       ▼                                    ▼
  Breach / ransomware                  Parchás antes de que lo exploten
```

## Relación con otros dominios

| Dominio | Relación |
|---------|----------|
| 02 - Aseguramiento | Security Hub agrega findings de Inspector con el resto |
| 03 - IAM | Inspector necesita permisos IAM; Access Analyzer complementa la visión |
| 04 - Detección | GuardDuty detecta explotación activa; Inspector detecta la vulnerabilidad antes |
| 06 - Infraestructura | Parchar vulnerabilidades detectadas por Inspector protege la infra |
| 08 - Aplicaciones | Inspector escanea código de Lambda y dependencias |

## Estructura de archivos

```
05-gestion-vulnerabilidades/
├── README.md                    ← estás acá
├── inspector.md                 ← Quick Win 11 completo
├── consola/
│   └── screenshots.md           ← capturas de la consola
└── cli-terraform/
    ├── commands.sh              ← comandos AWS CLI
    └── main.tf                  ← infraestructura como código