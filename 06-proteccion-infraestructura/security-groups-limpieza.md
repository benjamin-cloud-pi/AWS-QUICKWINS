# Limpieza de puertos riesgosos abiertos en SG

| Campo | Definición |
|-------|------------|
| Servicio principal | VPC Security Groups / AWS Systems Manager |
| Prioridad | Alta |
| Objetivo | Cerrar accesos administrativos abiertos a internet y reemplazarlos por métodos seguros |
| Riesgo mitigado | Fuerza bruta SSH/RDP, explotación de hosts expuestos, movimiento lateral y toma de control de instancias |

---

## ¿Que es y para que sirve?

Un Security Group controla el trafico permitido en nuestros recursos de AWS, por ejemplo una instancia EC2. AWS lo describe como un mecanismo que controla el trafico de entrada y salida asociado a recursos, actuando como firewall virtual

El QuickWin recomienda cerrar reglas de entrada hacia puertos administrativos 22/SHH y 3389/RDP cuando el origne es `0.0.0.0/0` o `::/0`

### Analogia

Es como dejar el cuarto de servidores abierto a la calle. Aunque tengas una llave en la puerta, cualquiera puede acercarse e intentar forzarla. La practica segura es no exponer esa puerta publicamente y usa un acceso interno controlado

---

## ¿Como funciona?

```text
1. Inventariar Security Groups
2. Detectar reglas riesgosas: TCP 22, TCP 3389 O All traffic desde 0.0.0.0/0 o ::/0
3. Confirmar si la exposicion es necesaria
4. Eliminar o restringir a IP corporatica/VPN/bastion
5. Reemplazar acceso administrativo por SSM, bastion o EC2 Instance Connect
6. Validar con Security Hub EC2.13/ EC2.14
```

AWS Security Manturity Model recomienda System Manager Fleet Manager porque no requiere abrir puertos inbound, o usar bastiones, si no se puede usar SSM, sugiere EC2 Instance Connect o restringir IPs

### Puertos a revisar primero

| Puerto | Servicio | Riesgo |
|--------|----------|--------|
| 22 | SSH | Fuerza bruta, acceso Linux |
| 3389 | RDP | Fuerza bruta, ransomware, acceso Windows |
| 3306 | MySQL | Exposición directa de base de datos |
| 5432 | PostgreSQL | Exposición directa de base de datos |
| 1433 | SQL Server | Exposición directa de base de datos |
| 0-65535 | All traffic | Exposición total accidental |

AWS documenta que HTTP 80 y HTTPS 443 suelen permitirse públicamente para servidores web; para bases de datos, recomienda fuentes específicas como rangos internos o Security Groups de aplicaciones. citeturn12search66

---

## 3. Relación con otros servicios

| Servicio | Relación |
|---|---|
| EC2 | Los Security Groups suelen aplicarse a instancias EC2 y controlan su acceso inbound/outbound. citeturn12search65 |
| VPC | Los Security Groups pertenecen a una VPC y se asocian a recursos dentro de esa red. citeturn12search65 |
| SSM Fleet/Session Manager | Alternativa recomendada para administrar instancias sin abrir puertos inbound. citeturn12search68 |
| Security Hub | Los controles EC2.13 y EC2.14 verifican que SGs no permitan SSH/RDP desde `0.0.0.0/0` o `::/0`. citeturn12search68 |
| Firewall Manager | Puede ofrecer más flexibilidad y opciones adicionales para gestionar políticas de SG, con coste adicional. citeturn12search68 |
| Terraform | El provider recomienda gestionar reglas como recursos separados `aws_vpc_security_group_ingress_rule` / `egress_rule` en lugar de reglas inline. citeturn12search55turn12search56 |

---

## 4. Consola

Ruta sugerida:

1. EC2 → Security Groups
2. Filtrar por reglas inbound con puerto 22 o 3389
3. Revisar origen `0.0.0.0/0` y `::/0`
4. Edit inbound rules → eliminar o restringir
5. Validar en Security Hub controles EC2.13 y EC2.14

---

## 5. CLI + Terraform

### Detectar SSH abierto a internet

```bash
aws ec2 describe-security-groups   --filters Name=ip-permission.from-port,Values=22             Name=ip-permission.to-port,Values=22             Name=ip-permission.cidr,Values=0.0.0.0/0   --query 'SecurityGroups[].{GroupId:GroupId,Name:GroupName,VpcId:VpcId}'   --output table
```

`describe-security-groups` permite describir Security Groups y filtrar por reglas inbound, puerto, protocolo y CIDR. citeturn12search49

### Detectar RDP abierto a internet

```bash
aws ec2 describe-security-groups   --filters Name=ip-permission.from-port,Values=3389             Name=ip-permission.to-port,Values=3389             Name=ip-permission.cidr,Values=0.0.0.0/0   --query 'SecurityGroups[].{GroupId:GroupId,Name:GroupName,VpcId:VpcId}'   --output table
```

### Detectar all traffic abierto

```bash
aws ec2 describe-security-groups   --filters Name=ip-permission.protocol,Values=-1             Name=ip-permission.cidr,Values=0.0.0.0/0   --query 'SecurityGroups[].{GroupId:GroupId,Name:GroupName,VpcId:VpcId}'   --output table
```

El protocolo `-1` representa all protocols/all traffic en filtros de Security Groups. citeturn12search52

### Terraform - patrón recomendado

```hcl
resource "aws_security_group" "admin" {
  name        = "admin-access-sg"
  description = "Admin access restricted by CIDR"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "ssh_restricted" {
  security_group_id = aws_security_group.admin.id
  description       = "SSH restricted to corporate/VPN CIDR"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.admin_cidr
}
```

HashiCorp recomienda usar recursos separados para reglas de SG y evitar reglas inline por problemas de gestión, IDs, tags y conflictos.

---