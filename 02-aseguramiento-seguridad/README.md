# Aseguramiento de la seguridad

## Descripcion 

Este dominio se enfoca en tener **visibilidad centralizada**  de tu postura de seguridad.
No alcanza con habilitar servicios de seguridad si despues nadie mira lo que pasa o mejor dicho hallazgos.
AWS Security hub es el servicio que agrega todo en un solo lugar y te da un score medible

se trabaja **1 Quickwin**


| # | QuickWin | Servicio principal | Prioridad |
|---|----------|-------------------|-----------|
| 3 | [Evaluar postura CSPM y centralizar hallazgos](./cspm-security-hub.md) | AWS Security Hub | Alta |

## ¿Por que es importante?

Porque sin Security Hub, los hallazgos de GuarDuty estan en un lugar, los de Inspector en otro, los de Macie en otro, y los de config en otro.
Nadie tiene la foto completa, Security Hub es el **centro de operaciones** que junta todo, lo normaliza y te dice: "tu postura de seguridad esta en x%"

## Relacion con otros dominios

```
                    ┌──────────────────────┐
                    │   02 - Security Hub   │
                    │   (este dominio)      │
                    └──────────┬───────────┘
                               │
             ┌─────────────────┼─────────────────┐
             │                 │                 │
             ▼                 ▼                 ▼
    ┌────────────────┐ ┌──────────────┐ ┌────────────────┐
    │ 03 - IAM       │ │ 04 - Detect  │ │ 07 - Datos     │
    │ Access Analyzer│ │ GuardDuty    │ │ Macie          │
    └────────────────┘ │ CloudTrail   │ └────────────────┘
                       └──────────────┘
              ▲                                  ▲
              │                                  │
    ┌─────────────────┐               ┌──────────────────┐
    │ 05 - Vulns      │               │ 06 - Infra       │
    │ Inspector       │               │ Security Groups  │
    └─────────────────┘               └──────────────────┘
```

Security hub **recibe** hallazgos de casi todo los otros dominios. Por eso se recomienda habilitarlo despues de tener los servicios base (IAM, CloudTrail, GuardDuty) configurados, para que tenga datos que agregar

## Estructura de archivos

```
02-aseguramiento-seguridad/
├── README.md                    ← estás acá
├── cspm-security-hub.md         ← Quick Win 3 completo
├── consola/
│   └── screenshots.md           ← capturas de la consola
└── cli-terraform/
    ├── commands.sh              ← comandos AWS CLI
    └── main.tf                  ← infraestructura como código
```
