# Terraform S3-Snowflake Integration with KMS Encryption

Este proyecto implementa una integración completa entre AWS S3 y Snowflake utilizando **encriptación KMS** para máxima seguridad de datos.

## 📋 Características

- ✅ **Encriptación KMS**: Bucket S3 encriptado con AWS KMS
- ✅ **S3 Bucket Key**: Reduce costos de KMS en ~99%
- ✅ **Rotación automática**: KMS key rotation habilitada
- ✅ **IAM seguro**: Permisos mínimos necesarios con External ID
- ✅ **Storage Integration**: Integración nativa Snowflake-S3 con KMS
- ✅ **External Stage**: Stage configurado para carga de datos
- ✅ **Lifecycle policies**: Gestión automática de versiones y archivos antiguos
- ✅ **Bloqueo público**: Bucket completamente privado

## 🏗️ Arquitectura

```
┌─────────────────┐
│   Snowflake     │
│  (Storage Int)  │
└────────┬────────┘
         │ Assume Role
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

## 📦 Estructura del Proyecto

```
terraform-s3-snowflake-kms/
├── providers.tf           # Configuración de providers AWS y Snowflake
├── variables.tf           # Definición de variables
├── outputs.tf             # Outputs con información útil
├── main.tf                # Orquestación principal
├── kms.tf                 # KMS key, alias y políticas
├── s3.tf                  # Bucket S3 con encriptación KMS
├── iam.tf                 # IAM role y políticas para Snowflake
├── snowflake.tf           # Database, schema, storage integration y stage
├── terraform.tfvars.example  # Plantilla de variables
├── .gitignore             # Archivos a ignorar en git
└── README.md              # Este archivo
```

## 🚀 Inicio Rápido

### Prerrequisitos

1. **Terraform** >= 1.0
2. **AWS CLI** configurado
3. **Cuenta Snowflake** con permisos de ACCOUNTADMIN
4. **Credenciales AWS** con permisos para crear:
   - KMS keys
   - S3 buckets
   - IAM roles y policies

### Paso 1: Clonar y Configurar

```bash
# Navegar al directorio
cd terraform-s3-snowflake-kms

# Copiar archivo de variables
cp terraform.tfvars.example terraform.tfvars

# Editar con tus credenciales
nano terraform.tfvars
```

### Paso 2: Configurar Variables

Edita `terraform.tfvars` con tus valores:

```hcl
# AWS
aws_access_key = "TU_AWS_ACCESS_KEY"
aws_secret_key = "TU_AWS_SECRET_KEY"
aws_account_id = "TU_ACCOUNT_ID"

# Snowflake
snowflake_user     = "TU_USUARIO"
snowflake_password = "TU_PASSWORD"
snowflake_account  = "TU_ACCOUNT"

# S3
s3_bucket_name = "mi-bucket-unico-kms"  # Debe ser único globalmente
```

### Paso 3: Desplegar

```bash
# Inicializar Terraform
terraform init

# Ver plan de ejecución
terraform plan

# Aplicar cambios
terraform apply
```

⚠️ **Importante**: El despliegue puede tardar 5-10 minutos debido a las dependencias entre recursos.

## 🔄 Proceso de Despliegue Automático

Este proyecto gestiona automáticamente las dependencias circulares entre AWS y Snowflake usando un approach de dos fases:

### Fase 1: Recursos Base
1. ✅ Crear KMS key con política dinámica
2. ✅ Crear bucket S3 con encriptación KMS
3. ✅ Crear IAM role con trust policy temporal

### Fase 2: Actualización Automática
1. ✅ Crear Storage Integration en Snowflake (genera External ID)
2. ✅ `null_resource` actualiza automáticamente la trust policy del IAM role con:
   - Snowflake IAM User ARN correcto
   - External ID del Storage Integration
3. ✅ Crear External Stage

**Nota**: El proceso es completamente automático. El `null_resource` en `iam_updated.tf` ejecuta `aws iam update-assume-role-policy` para actualizar el trust policy después de que el Storage Integration está creado.

## 📊 Outputs Importantes

Después del despliegue, obtendrás:

```bash
# Ver todos los outputs
terraform output

# Outputs específicos
terraform output kms_key_arn
terraform output s3_bucket_name
terraform output snowflake_iam_user_arn
```

### Outputs Clave:

- **kms_key_arn**: ARN de la KMS key para encriptación
- **kms_key_alias**: Alias amigable (alias/snowflake-s3-kms-stage)
- **s3_bucket_name**: Nombre del bucket creado
- **iam_role_arn**: ARN del role de Snowflake
- **snowflake_iam_user_arn**: Usuario IAM de Snowflake (crítico)
- **snowflake_external_id**: External ID para trust policy

## 🔍 Verificación Post-Despliegue

### 1. Verificar KMS Key

```bash
# Describir la key
aws kms describe-key --key-id alias/snowflake-s3-kms-stage --region eu-west-1

# Ver política
aws kms get-key-policy \
  --key-id alias/snowflake-s3-kms-stage \
  --policy-name default \
  --region eu-west-1
```

### 2. Verificar Encriptación S3

```bash
# Ver configuración de encriptación
aws s3api get-bucket-encryption --bucket <tu-bucket>

# Debe mostrar:
# "SSEAlgorithm": "aws:kms"
# "KMSMasterKeyID": "arn:aws:kms:..."
# "BucketKeyEnabled": true
```

### 3. Test de Carga de Archivos

```bash
# Crear archivo de prueba
echo "col1,col2\nvalue1,value2" > test.csv

# Subir a S3
aws s3 cp test.csv s3://<tu-bucket>/snowflake-data/

# Verificar encriptación del objeto
aws s3api head-object \
  --bucket <tu-bucket> \
  --key snowflake-data/test.csv \
  --query 'ServerSideEncryption,SSEKMSKeyId'

# Debe retornar:
# "ServerSideEncryption": "aws:kms"
# "SSEKMSKeyId": "arn:aws:kms:eu-west-1:..."
```

### 4. Verificar en Snowflake

```sql
-- Conectar a Snowflake
USE ROLE ACCOUNTADMIN;
USE DATABASE DEMO_KMS_V3;
USE SCHEMA DEMO_SCHEMA;

-- Verificar Storage Integration
DESC INTEGRATION S3_INTEGRATION_KMS;

-- Ver configuración de encriptación
SHOW PARAMETERS LIKE 'ENCRYPTION%' IN INTEGRATION S3_INTEGRATION_KMS;

-- Listar archivos en el stage
LIST @S3_STAGE_KMS;

-- Test de carga
CREATE OR REPLACE TABLE test_kms (
  col1 VARCHAR,
  col2 VARCHAR
);

COPY INTO test_kms
FROM @S3_STAGE_KMS
FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1);

SELECT * FROM test_kms;
```

## 💰 Consideraciones de Costos

### KMS Pricing (eu-west-1)

| Concepto | Costo |
|----------|-------|
| Key storage | ~$1/mes por key |
| API requests | $0.03 por 10,000 requests |

### 🎯 Optimización: S3 Bucket Key

✅ **Habilitado por defecto** en este proyecto

- Reduce requests a KMS en ~99%
- Ahorro significativo en buckets con muchos objetos
- Sin impacto en seguridad

**Ejemplo de ahorro:**
- Sin Bucket Key: 1M objetos = $3,000/mes en KMS
- Con Bucket Key: 1M objetos = ~$30/mes en KMS

## 🔐 Seguridad

### Características de Seguridad Implementadas:

1. **KMS Key Rotation**: Rotación automática anual
2. **External ID**: Previene confused deputy attack
3. **Least Privilege**: Permisos IAM mínimos necesarios
4. **Condition Keys**: KMS solo vía S3 service
5. **Public Block**: Bucket completamente privado
6. **Versioning**: Protección contra borrado accidental
7. **Bucket Policy**: Restricción a IAM role específico

### Políticas de KMS Key:

La KMS key permite:
- ✅ Root account: Administración completa
- ✅ S3 service: Encrypt/Decrypt para el bucket
- ✅ IAM Role Snowflake: Decrypt vía S3
- ✅ Snowflake IAM User: Decrypt vía S3

## 🚨 Solución de Problemas

### Error: "Access Denied - KMS"

**Causa**: Snowflake no puede usar la KMS key

**Solución**:
```bash
# Verificar política de KMS
aws kms get-key-policy --key-id alias/snowflake-s3-kms-stage --policy-name default

# Verificar que incluye el Snowflake IAM User ARN
terraform output snowflake_iam_user_arn
```

### Error: "The ciphertext refers to a customer master key that does not exist"

**Causa**: KMS key ARN incorrecto en Storage Integration

**Solución**:
```sql
-- Verificar en Snowflake
DESC INTEGRATION S3_INTEGRATION_KMS;

-- Re-aplicar Terraform
terraform apply -refresh-only
terraform apply
```

### Error: Trust Policy Incorrecto

**Causa**: IAM role tiene un External ID antiguo o incorrecto

**Solución**:
```bash
# El null_resource debería actualizar automáticamente el trust policy
# Si no funciona, ejecuta manualmente:
terraform taint null_resource.update_iam_trust_policy
terraform apply

# O verifica el External ID correcto:
terraform output snowflake_external_id
```

### Nota sobre Dependencias Circulares

✅ **Este problema está resuelto automáticamente** por el proyecto usando `null_resource`.

El approach de dos fases maneja la dependencia circular:
1. IAM role se crea con trust policy temporal
2. Storage Integration se crea y genera External ID
3. `null_resource` actualiza automáticamente el trust policy con valores correctos

No necesitas intervenir manualmente.

## 🔄 Actualización del Proyecto

### Cambiar nombre del bucket:

```bash
# Editar terraform.tfvars
s3_bucket_name = "nuevo-nombre-bucket"

# Aplicar (creará nuevo bucket, el anterior debe eliminarse manualmente)
terraform apply
```

### Cambiar región:

```bash
# Editar terraform.tfvars
aws_region = "us-east-1"

# Destruir recursos existentes
terraform destroy

# Volver a crear en nueva región
terraform apply
```

## 🗑️ Limpieza

Para destruir todos los recursos:

```bash
# Ver qué se va a destruir
terraform plan -destroy

# Destruir todo
terraform destroy

# Confirmar con: yes
```

⚠️ **Advertencia**: 
- La KMS key entrará en periodo de eliminación (10 días por defecto)
- Los objetos en S3 se eliminarán permanentemente
- La Storage Integration en Snowflake se eliminará

## 📚 Referencias

- [Snowflake: Using AWS KMS](https://docs.snowflake.com/en/user-guide/data-load-s3-kms)
- [AWS KMS Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
- [S3 Bucket Keys](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-key.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Snowflake Provider](https://registry.terraform.io/providers/Snowflake-Labs/snowflake/latest/docs)

## 🤝 Soporte

Si encuentras problemas:

1. Verifica los logs de Terraform: `terraform show`
2. Revisa los outputs: `terraform output`
3. Consulta la sección de solución de problemas
4. Verifica las políticas de IAM y KMS manualmente

## 📝 Notas Importantes

- ⚠️ **Credenciales sensibles**: Nunca commitees `terraform.tfvars`
- ⚠️ **State file**: El archivo `.tfstate` contiene información sensible
- ⚠️ **KMS deletion**: Las keys tienen periodo de espera antes de eliminarse
- ⚠️ **Costos**: Monitorea el uso de KMS API calls
- ✅ **Bucket Key**: Ya está habilitado para reducir costos
- ✅ **Rotación automática**: La KMS key rota anualmente

## ✅ Checklist de Implementación

- [x] Crear KMS key con rotación automática
- [x] Configurar política de KMS key
- [x] Actualizar encriptación de S3 a aws:kms
- [x] Activar S3 Bucket Key para reducir costos
- [x] Añadir permisos KMS al IAM role de Snowflake
- [x] Configurar Storage Integration con KMS
- [x] Crear External Stage
- [x] Documentar proceso de verificación
- [ ] Test completo de carga de datos
- [ ] Configurar CloudTrail para auditar KMS (opcional)
- [ ] Implementar CloudWatch alarms (opcional)

## 📊 Próximos Pasos Recomendados

1. **Configurar CloudTrail** para auditar accesos a KMS:
```hcl
resource "aws_cloudtrail" "kms_audit" {
  name           = "kms-audit-trail"
  s3_bucket_name = "audit-logs-bucket"
  
  event_selector {
    read_write_type = "All"
    include_management_events = true
    
    data_resource {
      type   = "AWS::KMS::Key"
      values = [aws_kms_key.snowflake_s3.arn]
    }
  }
}
```

2. **Configurar CloudWatch Alarms** para fallos de KMS
3. **Implementar Tags adicionales** para cost allocation
4. **Configurar backup** del state file en S3 backend

---

**Versión**: 1.0  
**Última actualización**: Noviembre 2025  
**Autor**: Terraform S3-Snowflake-KMS Integration Project
