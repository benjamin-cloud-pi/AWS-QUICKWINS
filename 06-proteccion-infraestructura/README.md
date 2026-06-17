# Proteccion de la Infraestructura

## Descripcion

Este dominio se centra en reducir la superficie de exposicion de red, especialmente evitando que puertos administrativos como SSH 22 y RDP 3389 queden abiertos a internet (`0.0.0.0/0` 0 `::/0`). El Quickwin de AWS recomiend cerrar esos puertos y usar alternativas como AWS System Manager Fleet Manager, bastiones endurecidos, EC2 Instance Connect o rangos de IP restringidos

## Quickwin que tocaremos

| # | QuickWin | Servicio principal | Prioridad |
|---|----------|-------------------|-----------|
| 12 | [Limpieza de puertos riesgosos abiertos](./security-groups-limpieza.md) | VPC Security Groups / SSM | Alta |

## ¿Por que importa?

Los Security Group funcionan como un firewall virtual asociado a recursos como EC2, controla trafico entrante y saliente mediante reglas de protocolo, puerto y orginen/destino. Si permitimos SSH/RDP desde todo internet, aumentas la superficie de ataques y quedas expuesto a ataques de fuerza bruta, explotacion de hosts sin parches y accesos no autorizados

```text
Internet -> 0.0.0.0/0 -> SG con SSH 22 abierto -> EC2 -> Riesgo

Alternativa que se recomienda:
Usuario admin -> SSM Session/Fleet Manager -> EC2 privada sin abrir puertos inbound
``` 

## Estructura 

```text
06-proteccion-infraestructura/
├── README.md
├── security-groups-limpieza.md
├── consola/
│   └── screenshots.md
└── cli-terraform/
    ├── commands.sh
    └── main.tf
```
