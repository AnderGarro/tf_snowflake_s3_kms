# Terraform S3-Snowflake Integration with KMS Encryption

[![Terraform](https://img.shields.io/badge/Terraform-≥1.0-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-KMS%20%7C%20S3%20%7C%20IAM-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![Snowflake](https://img.shields.io/badge/Snowflake-Storage%20Integration-29B5E8?logo=snowflake)](https://www.snowflake.com/)

Proyecto Terraform que implementa una integración completa y segura entre **AWS S3** y **Snowflake** utilizando **encriptación KMS** para máxima protección de datos.

## 🌟 Características

- ✅ **Encriptación KMS**: Bucket S3 encriptado con AWS KMS y rotación automática de keys
- ✅ **S3 Bucket Key**: Optimización de costos KMS (~99% reducción)
- ✅ **IAM Seguro**: Permisos mínimos necesarios con External ID
- ✅ **Gestión Automática**: Dependencias circulares resueltas automáticamente
- ✅ **Storage Integration**: Integración nativa Snowflake-S3 con KMS
- ✅ **External Stage**: Stage configurado para carga y descarga de datos
- ✅ **Lifecycle Policies**: Gestión automática de versiones y archivos antiguos
- ✅ **Seguridad Total**: Bucket completamente privado con múltiples capas de seguridad

## 🏗️ Arquitectura

```
┌─────────────────┐
│   Snowflake     │
│  (Storage Int)  │
└────────┬────────┘
         │ Assume Role (con External ID)
         ↓
┌─────────────────┐      ┌──────────────┐
│   IAM Role      │─────→│   KMS Key    │
│  (Trust Policy) │      │  (Rotation)  │
└────────┬────────┘      └──────┬───────┘
         │                      │
         │ S3 + KMS Perms       │ Encrypt/Decrypt
         ↓                      ↓
┌────────────────────────────────┐
│        S3 Bucket               │
│  - SSE-KMS Encryption          │
│  - Bucket Key Enabled          │
│  - Versioning                  │
│  - Lifecycle Rules             │
└────────────────────────────────┘
```

## 🔧 Solución Técnica: Dependencias Circulares

Este proyecto resuelve automáticamente la dependencia circular entre IAM Role y Storage Integration usando un **approach de dos fases**:

1. **Fase 1**: Crear IAM role con trust policy temporal
2. **Storage Integration**: Snowflake crea integration y genera External ID
3. **Fase 2**: `null_resource` ejecuta `aws iam update-assume-role-policy` automáticamente

**Resultado**: Despliegue 100% automático con un solo `terraform apply`

## 🚀 Inicio Rápido

### Prerrequisitos

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configurado
- Cuenta Snowflake con permisos de ACCOUNTADMIN
- Credenciales AWS con permisos para KMS, S3, IAM

### Instalación

```bash
# Clonar repositorio
git clone https://github.com/AnderGarro/tf_snowflake_s3_kms.git
cd tf_snowflake_s3_kms

# Copiar y configurar variables
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Editar con tus credenciales

# Inicializar Terraform
terraform init

# Desplegar
terraform apply
```

⏱️ El despliegue completo tarda ~5-10 minutos.

## 📋 Configuración

Edita `terraform.tfvars` con tus valores:

```hcl
# AWS
aws_region     = "eu-west-1"
aws_account_id = "TU_ACCOUNT_ID"
aws_access_key = "TU_ACCESS_KEY"
aws_secret_key = "TU_SECRET_KEY"

# S3
s3_bucket_name = "mi-bucket-unico"  # Debe ser único globalmente

# Snowflake
snowflake_account  = "TU_ACCOUNT"
snowflake_user     = "TU_USUARIO"
snowflake_password = "TU_PASSWORD"
snowflake_database = "DEMO_KMS_V3"
```

## 📁 Estructura del Proyecto

```
tf_snowflake_s3_kms/
├── providers.tf          # Configuración de providers (AWS, Snowflake, null)
├── variables.tf          # Variables de entrada
├── main.tf               # Orquestación principal
├── kms.tf                # KMS key con rotación automática
├── s3.tf                 # Bucket S3 con encriptación KMS
├── iam.tf                # IAM role con trust policy inicial
├── iam_updated.tf        # ⭐ Auto-actualización trust policy
├── snowflake.tf          # Database, schema, storage integration, stage
├── outputs.tf            # Outputs del deployment
│
├── README.md             # Documentación completa
├── QUICKSTART.md         # Guía rápida de inicio
├── ARCHITECTURE.md       # Diagramas detallados
├── DEPLOYMENT_NOTES.md   # Notas técnicas
│
├── commands.sh           # Script interactivo con comandos útiles
├── test_snowflake.sql    # Tests SQL completos
└── test_snowflake_connection.sql  # Test rápido
```

## 🔐 Seguridad

### Características Implementadas

- **KMS Key Rotation**: Rotación automática anual de keys
- **External ID**: Previene confused deputy attacks
- **Least Privilege**: Permisos IAM mínimos necesarios
- **Condition Keys**: KMS solo vía S3 service (`kms:ViaService`)
- **Public Block**: Bucket completamente privado
- **Versioning**: Protección contra borrado accidental
- **Bucket Policy**: Restricción a IAM role específico
- **Multi-layer Security**: 5 capas de seguridad (ver `ARCHITECTURE.md`)

### Datos Sensibles Protegidos

El `.gitignore` excluye automáticamente:
- `*.tfvars` (credenciales)
- `*.tfstate` (información de recursos)
- Archivos de test con datos reales
- Backups y archivos temporales

## 🧪 Verificación Post-Despliegue

### AWS

```bash
# Verificar KMS
aws kms describe-key --key-id alias/snowflake-s3-kms-stage --region eu-west-1

# Verificar encriptación S3
terraform output s3_bucket_name | xargs -I {} aws s3api get-bucket-encryption --bucket {}

# Test de subida
aws s3 cp test.csv s3://$(terraform output -raw s3_bucket_name)/snowflake-data/
```

### Snowflake

```sql
USE ROLE ACCOUNTADMIN;
USE DATABASE DEMO_KMS_V3;
USE SCHEMA DEMO_SCHEMA;

-- Verificar Storage Integration
DESC INTEGRATION S3_INTEGRATION_KMS;

-- Listar archivos
LIST @S3_STAGE_KMS;

-- Test de carga
CREATE TABLE test_load (col1 STRING, col2 STRING);
COPY INTO test_load FROM @S3_STAGE_KMS FILE_FORMAT = (TYPE = CSV);
SELECT * FROM test_load;
```

## 💰 Optimización de Costos

### S3 Bucket Key Habilitado

- ✅ Reduce KMS API calls en ~99%
- ✅ Sin impacto en seguridad
- ✅ Ahorro significativo:
  - **Sin Bucket Key**: 1M objetos = ~$3,000/mes
  - **Con Bucket Key**: 1M objetos = ~$30/mes

### Lifecycle Policies

- Transición a IA después de 30 días
- Transición a Glacier después de 90 días
- Eliminación de versiones antiguas automática

## 📊 Outputs Principales

Después del despliegue:

```bash
terraform output

# Outputs incluyen:
# - kms_key_arn: ARN de la KMS key
# - s3_bucket_name: Nombre del bucket creado
# - iam_role_arn: ARN del role de Snowflake
# - snowflake_iam_user_arn: Usuario IAM de Snowflake
# - snowflake_external_id: External ID para trust policy
# - verification_commands: Comandos para verificar el deployment
```

## 🔄 Actualización

```bash
# Cambiar configuración en terraform.tfvars
nano terraform.tfvars

# Ver cambios
terraform plan

# Aplicar
terraform apply

# El null_resource actualizará el trust policy automáticamente si es necesario
```

## 🗑️ Limpieza

```bash
# Destruir todos los recursos
terraform destroy

# ⚠️ Advertencia: 
# - La KMS key entrará en periodo de eliminación (10 días)
# - Los objetos en S3 se eliminarán permanentemente
```

## 🚨 Troubleshooting

### Error: "Could not assume role"

✅ **Resuelto automáticamente** por `null_resource.update_iam_trust_policy`

Si persiste:
```bash
terraform taint null_resource.update_iam_trust_policy
terraform apply
```

### Error: "Access Denied - KMS"

Verifica la política de KMS:
```bash
aws kms get-key-policy --key-id alias/snowflake-s3-kms-stage --policy-name default
```

Ver más soluciones en `README.md` y `DEPLOYMENT_NOTES.md`.

## 📚 Documentación

- **[README.md](README.md)** - Documentación completa del proyecto
- **[QUICKSTART.md](QUICKSTART.md)** - Guía de inicio en 5 minutos
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Diagramas y arquitectura detallada
- **[DEPLOYMENT_NOTES.md](DEPLOYMENT_NOTES.md)** - Notas técnicas y approach

## 🤝 Contribuir

Las contribuciones son bienvenidas! Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📝 Licencia

Este proyecto está bajo la Licencia MIT. Ver `LICENSE` para más información.

## 🔗 Referencias

- [Snowflake: Using AWS KMS](https://docs.snowflake.com/en/user-guide/data-load-s3-kms)
- [AWS KMS Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
- [S3 Bucket Keys](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-key.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Snowflake Provider](https://registry.terraform.io/providers/Snowflake-Labs/snowflake/latest/docs)

## ⭐ Agradecimientos

Si este proyecto te fue útil, considera darle una estrella ⭐ en GitHub!

---

**Autor**: Ander Garro  
**Última actualización**: Noviembre 2025  
**Versión**: 1.0
