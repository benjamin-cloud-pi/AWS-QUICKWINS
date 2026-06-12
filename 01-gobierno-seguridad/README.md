# Gobierno de la seguridad

## Descripcion

En este modulo se cubren las configuraciones en base de la cuenta AWS que establecen los cimientos para todo lo que viene despues. Son los primeros pasos a nivel organizacion que deberiamos hacer, tambien a la hora de habilitar cualquier servicio de seguridad

se trabajan en **2 Quickwins**

| # | QuickWin | Servicio principal | Prioridad |
|---|----------|--------------------|-----------|
| 1 | [Contactos de seguridad](./contactos-seguridad.md) | AWS Account / Organizations | Alta |
| 2 | [Selección de regiones](./seleccion-regiones.md) | Organizations / SCP | Alta |

## ¿Por que comenzar aca?

Porque si AWS detecta un incidente en tu cuenta y no tiene a quien avisarle, o si alguien despliega un cryptominer en una region que nadie monitorea, ningun otro control de seguridad importa.

## Relacion con otros dominios

```
01-Gobierno
├── Contactos de seguridad ──► Reciben alertas de GuardDuty, Security Hub, Abuse
└── Selección de regiones ──► Limita dónde aplican CloudTrail, GuardDuty, Config, etc.
```

## Estructura de archivos

```
01-gobierno-seguridad/
├── README.md                    
├── contactos-seguridad.md       
├── seleccion-regiones.md        
├── consola/
│   └── screenshots.md           
└── cli-terraform/
    ├── commands.sh              
    └── main.tf                  
```