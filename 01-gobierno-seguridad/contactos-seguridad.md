# Modulo 1: Mantener actualizados los contactos de seguridad

| Campo | Definición |
|-------|------------|
| **Servicio principal** | AWS Account / AWS Organizations |
| **Prioridad** | Alta |
| **Objetivo** | Asegurar que AWS pueda contactar al equipo correcto ante incidentes, abuso, credenciales expuestas o actividad sospechosa |
| **Riesgo mitigado** | Alertas críticas no atendidas por correos desactualizados o casillas no monitoreadas |

---

## ¿Que es y para que sirve?

AWS permite configurar **contactos alternativos** (Billing, Operations, Security) ademas del correo del root. El contacto de seguridad es el que recibe notificaciones criticas cuando AWS detecta actividad sospechosa, credenciales expuestas en GitHub, abuso de tu cuenta, etc.

Si no lo configuras, esas alertas van al correo root, que muchas veces nadie monitorea activamente.

> **En resumen:** es decirle a AWS "Si pasa algo en esta cuenta mientras me voy a mar del plata, avisale a esta gente"

---

## ¿Como funciona?

1. Vas a **Account Settings -> Alternate Contacts** en la consola / UI
2. Completas nombre, correo y telefono del contacto de seguridad
3. AWS usa ese correo para enviar notificaciones de seguridad 
4. En **Organizacion**, podes administrar contactos centralizado desde la managment account

## Buenas practicas 

- Usar una **Lista de distribucion**, no un correo personal
- Incluir al menos 2-3 responsables en esa lista
- Mantener actualizado el telefono de recuperacion
- Administrar contactos desde AWS organizations 
- Revisar contactos en **Todas** las cuentas

### Validacion minima 

- [] Security Contact configurado y probado
- [] Correo monitoreado por mas de una persona
- [] Telefono de recuperacion actualizado
- [] Contactos revisados en todas las cuentas

## Relacion con otros Servicios 


| Se relaciona con | Tipo | ¿Cómo? |
|---|---|---|
| **AWS Organizations** | Directo | Permite administrar contactos de todas las cuentas miembro desde la management account |
| **GuardDuty** | Indirecto | Los findings High/Critical pueden generar notificaciones que llegan al contacto de seguridad |
| **Security Hub** | Indirecto | Los hallazgos agregados de Security Hub se notifican al contacto configurado |
| **AWS Abuse** | Directo | AWS envía reportes de abuso (spam, DDoS desde tu cuenta) al security contact |
| **CloudTrail** | Indirecto | Si se detectan credenciales root comprometidas, la alerta va al security contact |
| **IAM** | Indirecto | Se necesitan permisos `account:PutAlternateContact` para modificar contactos por CLI/API |

### Diagrama de ejemplo 

```
AWS detecta incidente
        │
        ▼
┌─────────────────┐     ┌──────────────────┐
│  Abuse Report   │────►│                  │
│  GuardDuty      │────►│  Security Contact│────► Lista de distribución
│  Credentials    │────►│  (email)         │      equipo-seguridad@empresa.com
│  exposed        │────►│                  │
└─────────────────┘     └──────────────────┘
                               │
    ─────────┐
                    ▼          ▼          ▼
                Persona 1  Persona 2  Persona 3            
```

## Consola

> Ver caputra en [`consola/screenshots.md`](./consola/screenshots.md)

**Ruta desde consola**

1. AWS Console -> **Account** (esquina superior derecha, click en nombre de la cuenta)
2. Seccion **Alternate Contacts**
3. Completar **Security** con nombre, email y telefono

**En Organizations:**

1. AWS Organizations -> **Accounts**
2. Seleccionar cuenta miembro
3. **Account settings** -> **Alternate contacts** -> Editar

---

> Ver archivos completos en [`cli-terraform/`](./cli-terrafom/)

### CLI - Verificar contacto actual

```bash
aws account get-alternate-contact \
    --alternate-contact-type SECURITY
```

### CLI - Configurar contacto de seguridad 

```bash
aws account put-alternate-contact \
    --alternate-contact-type SECURITY \
    --name "Equipo de seguridad" \
    --title "Security Team" \
    --email-address "security-team@empresa.com" \
    --phone-number "+54 943943093"
```

### CLI - Para una cuenta miembro (desde management account)

```bash
aws account put-alternate-contact \
    --account-id 12345566 \
    --alternate-contact-type SECURITY \
    --name "Equipo de Seguridad"
    --title "Security Team" \
    --email-address "security-team@empresa.com" \
    --phone-number "+54 44234423"
```

### Terraform 

```hcl
resource "aws_account_alternate_contact" "security" {
    alternate_contact_type = "SECURITY"
    name                   = "Equipo de seguridad"
    title                  = "Security Team"
    email_address          = "security-team@empresa.com"
    phone_number           = "+54 332434324"    
}
``` 

### Referencias 

- [AWS - Update alternate contacts](https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-update-contact-alternate.html)
- [AWS re:Post - Configuring a security contact](https://www.repost.aws/articles/ARKAOWeFpMRD6iDt_q3xBXDQ/configuring-a-security-contact-for-your-aws-account)
- [Terraform - aws_account_alternate_contact](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/account_alternate_contact)
- [AWS Blog - Manage alternate contacts with Terraform](https://aws.amazon.com/blogs/mt/manage-aws-account-alternate-contacts-with-terraform/)
