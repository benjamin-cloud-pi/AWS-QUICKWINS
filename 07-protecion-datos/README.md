# Proteccion de Datos

## Descripcion

La proteccion de datos se enfoca en evita que informacion sensible quede expuesta accidentalmente y en cubrir donde se almacena data clasificada (PII, Credenciales, datos financieros). Se trabajan **2 QuickWins**:

| # | QuickWin | Servicio principal | Prioridad |
|---|----------|-------------------|-----------|
| 13 | [Bloquear acceso público a S3/AMI/EBS](./s3-bpa.md) | S3 Block Public Access | Alta |
| 14 | [Descubrimiento de datos sensibles](./macie.md) | Amazon Macie | Alta |

## ¿Por qué importa?

```text
Sin protección:                        Con protección:

  Bucket S3 público                      S3 BPA activado a nivel cuenta
  con datos de clientes                       │
       │                                      ▼
       ▼                                 Imposible hacer público
  Google indexa el bucket                     +
       │                               Macie descubre PII en S3
       ▼                                      │
  Breach en las noticias                      ▼
  Multa GDPR/regulatoria                 Alertás y remediás antes
                                         de que alguien lo encuentre
```

## Dos capas complementarias

```text
┌──────────────────────────────────┐
│    CAPA 1: PREVENCIÓN            │
│    S3 Block Public Access        │
│    (evita exposición accidental) │
└───────────────┬──────────────────┘
                │
                ▼
┌──────────────────────────────────┐
│    CAPA 2: DETECCIÓN             │
│    Amazon Macie                  │
│    (descubre datos sensibles)    │
└──────────────────────────────────┘
```

## Estructura

```text
07-proteccion-datos/
├── README.md                    ← estás acá
├── s3-bpa.md                    ← Quick Win 13
├── macie.md                     ← Quick Win 14
├── consola/
│   └── screenshots.md
└── cli-terraform/
    ├── commands.sh
    └── main.tf
```