# Notas de Despliegue - S3-Snowflake-KMS Integration

## ✅ Estado Actual

**Versión**: V3  
**Bucket S3**: `s3-snow-kms-test-v3`  
**Database Snowflake**: `DEMO_KMS_V3`  
**Última actualización**: 13 noviembre 2025

---

## 🔧 Approach Implementado

### Gestión de Dependencias Circulares

El proyecto usa un **approach de dos fases automático** para resolver la dependencia circular entre IAM Role y Storage Integration:

#### Archivos Clave:
- **`iam.tf`**: Define IAM role con trust policy temporal inicial
- **`iam_updated.tf`**: Contiene `null_resource` que actualiza automáticamente el trust policy

#### Flujo:
1. **Fase 1**: Crear recursos base (KMS, S3, IAM role con trust temporal)
2. **Storage Integration**: Snowflake crea integration y genera External ID
3. **Fase 2**: `null_resource` ejecuta `aws iam update-assume-role-policy` automáticamente
4. **Resultado**: Trust policy actualizado con External ID correcto

### Comando Terraform:
```bash
terraform init
terraform apply  # Todo automático
```

---

## 📁 Estructura de Archivos

### Terraform Core
- `providers.tf` - Configuración de providers (AWS, Snowflake, null)
- `variables.tf` - Variables de entrada
- `terraform.tfvars` - Valores actuales (no commiteado)
- `terraform.tfvars.example` - Plantilla de ejemplo
- `outputs.tf` - Outputs del deployment

### Recursos AWS
- `kms.tf` - KMS key con rotación automática
- `s3.tf` - Bucket S3 con encriptación KMS y Bucket Key
- `iam.tf` - IAM role con trust policy inicial
- `iam_updated.tf` - ⭐ Actualización automática del trust policy

### Recursos Snowflake
- `snowflake.tf` - Database, Schema, Storage Integration y Stage
- `main.tf` - Orquestación principal

### Documentación
- `README.md` - Documentación completa
- `QUICKSTART.md` - Guía rápida de inicio
- `ARCHITECTURE.md` - Diagramas y arquitectura
- `DEPLOYMENT_NOTES.md` - Este archivo

### Scripts y Tests
- `commands.sh` - Script interactivo con comandos útiles
- `test_snowflake.sql` - Tests completos SQL
- `test_snowflake_connection.sql` - Test rápido de conexión
- `test_data.csv` - Datos de prueba

---

## 🔑 Configuración Actual

### AWS
- **Account ID**: 997439898896
- **Region**: eu-west-1
- **KMS Key**: c7016ba4-8ae7-4785-bd34-39a6cba5a2a2
- **KMS Alias**: alias/snowflake-s3-kms-stage
- **S3 Bucket**: s3-snow-kms-test-v3
- **IAM Role**: snowflake-s3-kms-role

### Snowflake
- **Account**: RAGRCLW-SN28326
- **Database**: DEMO_KMS_V3
- **Schema**: DEMO_SCHEMA
- **Storage Integration**: S3_INTEGRATION_KMS
- **Stage**: S3_STAGE_KMS
- **IAM User**: arn:aws:iam::260512157176:user/5c391000-s
- **External ID**: ZR06009_SFCRole=5_ybpwUyzo15mUE02SzFNSaSI75DM=

---

## 🧪 Verificación Rápida

### AWS
```bash
# KMS Key
aws kms describe-key --key-id alias/snowflake-s3-kms-stage --region eu-west-1

# S3 Encryption
aws s3api get-bucket-encryption --bucket s3-snow-kms-test-v3 --region eu-west-1

# IAM Trust Policy
aws iam get-role --role-name snowflake-s3-kms-role --region eu-west-1 \
  --query 'Role.AssumeRolePolicyDocument'

# Test upload
aws s3 cp test_data.csv s3://s3-snow-kms-test-v3/snowflake-data/

# Verify encryption
aws s3api head-object --bucket s3-snow-kms-test-v3 \
  --key snowflake-data/test_data.csv --region eu-west-1 \
  --query '{Encryption: ServerSideEncryption, KMSKey: SSEKMSKeyId}'
```

### Snowflake
```sql
USE ROLE ACCOUNTADMIN;
USE DATABASE DEMO_KMS_V3;
USE SCHEMA DEMO_SCHEMA;

-- Ver Storage Integration
DESC INTEGRATION S3_INTEGRATION_KMS;

-- Listar archivos
LIST @S3_STAGE_KMS;

-- Test load
CREATE OR REPLACE TABLE test_load (
  nombre STRING,
  edad INTEGER,
  ciudad STRING
);

COPY INTO test_load
FROM @S3_STAGE_KMS/test_data.csv
FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1);

SELECT * FROM test_load;
```

---

## 🚨 Troubleshooting

### Error: "Could not assume role"

✅ **Resuelto automáticamente** por `null_resource.update_iam_trust_policy`

Si persiste:
```bash
# Forzar actualización del trust policy
terraform taint null_resource.update_iam_trust_policy
terraform apply
```

### Error: "Access Denied - KMS"

Verifica que la KMS key policy incluye el Snowflake IAM User:
```bash
aws kms get-key-policy \
  --key-id alias/snowflake-s3-kms-stage \
  --policy-name default \
  --region eu-west-1
```

### Verificar Estado Completo

```bash
# Ver todos los outputs
terraform output

# Ver estado de recursos
terraform state list

# Verificar null_resource
terraform state show null_resource.update_iam_trust_policy
```

---

## 📝 Mantenimiento

### Actualizar Trust Policy Manualmente (si es necesario)

```bash
# Obtener valores actuales
EXTERNAL_ID=$(terraform output -raw snowflake_external_id)
IAM_USER=$(terraform output -raw snowflake_iam_user_arn)

# Actualizar
aws iam update-assume-role-policy \
  --role-name snowflake-s3-kms-role \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
      \"Effect\": \"Allow\",
      \"Principal\": {\"AWS\": \"$IAM_USER\"},
      \"Action\": \"sts:AssumeRole\",
      \"Condition\": {
        \"StringEquals\": {\"sts:ExternalId\": \"$EXTERNAL_ID\"}
      }
    }]
  }"
```

### Recrear Storage Integration

Si necesitas recrear el Storage Integration:
```bash
# Eliminar
terraform destroy -target=snowflake_stage.s3_stage
terraform destroy -target=snowflake_storage_integration.s3_integration_kms

# Recrear
terraform apply
```

### Cambiar a Nuevo Bucket

```bash
# Editar terraform.tfvars
s3_bucket_name = "s3-snow-kms-test-v4"

# Aplicar
terraform apply

# El null_resource se ejecutará automáticamente
```

---

## 💡 Mejores Prácticas

1. **Siempre ejecutar `terraform plan` antes de `apply`**
2. **El `null_resource` se ejecuta automáticamente cuando cambian**:
   - External ID del Storage Integration
   - IAM User ARN del Storage Integration
   - Nombre del IAM Role
3. **No elimines `iam_updated.tf`** - es crítico para la gestión automática
4. **Usa `terraform refresh`** después de cambios manuales en AWS/Snowflake
5. **Mantén `terraform.tfvars` fuera de git** (ya está en .gitignore)

---

## 🔗 Referencias

- **README.md** - Documentación completa del proyecto
- **QUICKSTART.md** - Inicio rápido en 5 minutos
- **ARCHITECTURE.md** - Diagramas detallados de arquitectura
- **commands.sh** - 13 comandos útiles interactivos

---

**Última verificación**: 13 noviembre 2025  
**Estado**: ✅ Funcionando correctamente  
**Approach**: Dependencias circulares resueltas automáticamente
