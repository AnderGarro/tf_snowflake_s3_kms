# Guía de Inicio Rápido - Terraform S3-Snowflake-KMS

## 🚀 Despliegue en 5 Minutos

### Paso 1: Verificar Prerrequisitos

```bash
# Verificar Terraform
terraform version
# Debe mostrar: Terraform v1.0+

# Verificar AWS CLI
aws --version
aws sts get-caller-identity
# Debe mostrar tu Account ID: 997439898896

# Verificar credenciales
cat terraform.tfvars | grep -v "password\|secret"
```

### Paso 2: Inicializar

```bash
terraform init
```

Deberías ver:
```
Terraform has been successfully initialized!
```

### Paso 3: Desplegar (Opción Recomendada)

**Opción A - Despliegue en Fases (Recomendado):**

```bash
# Fase 1: KMS
terraform apply -target=aws_kms_key.snowflake_s3 -target=aws_kms_alias.snowflake_s3 -auto-approve

# Fase 2: S3
terraform apply -target=aws_s3_bucket.snowflake_stage -auto-approve

# Fase 3: IAM
terraform apply -target=aws_iam_role.snowflake_role -auto-approve

# Fase 4: Snowflake Database y Schema
terraform apply -target=snowflake_database.demo -target=snowflake_schema.demo -auto-approve

# Fase 5: Storage Integration
terraform apply -target=snowflake_storage_integration.s3_integration_kms -auto-approve

# Fase 6: Finalizar todo
terraform apply -auto-approve
```

**Opción B - Despliegue Completo:**

```bash
terraform apply
# Escribe: yes
```

**Opción C - Usar el Script Interactivo:**

```bash
./commands.sh
# Selecciona opción 4: "Aplicar en fases"
```

### Paso 4: Verificar Outputs

```bash
terraform output
```

Deberías ver algo como:

```
kms_key_arn = "arn:aws:kms:eu-west-1:997439898896:key/xxxx-xxxx-xxxx"
kms_key_alias = "alias/snowflake-s3-kms-stage"
```bash
# S3 Bucket name (debe ser único globalmente)
s3_bucket_name = "s3-snow-kms-test-v3"
iam_role_arn = "arn:aws:iam::997439898896:role/snowflake-s3-kms-role"
snowflake_iam_user_arn = "arn:aws:iam::260512157176:user/xxxx"
```

### Paso 5: Verificar en AWS

```bash
# Verificar KMS
aws kms describe-key --key-id alias/snowflake-s3-kms-stage --region eu-west-1

# Verificar encriptación S3
aws s3api get-bucket-encryption --bucket s3-snow-kms-test-v3
```

Deberías ver:
```json
{
    "SSEAlgorithm": "aws:kms",
    "KMSMasterKeyID": "arn:aws:kms:eu-west-1:...",
    "BucketKeyEnabled": true
}
```

### Paso 6: Test de Subida

```bash
# Crear archivo de prueba
echo "id,name,value
1,test1,100
2,test2,200" > test.csv

# Subir a S3
aws s3 cp test.csv s3://s3-snow-kms-test-v3/snowflake-data/

# Verificar encriptación
aws s3api head-object \
  --bucket s3-snow-kms-test-v3 \
  --key snowflake-data/test.csv \
  --query '{Encryption: ServerSideEncryption, KMSKeyId: SSEKMSKeyId}'
```

Deberías ver:
```json
{
    "Encryption": "aws:kms",
    "KMSKeyId": "arn:aws:kms:eu-west-1:997439898896:key/xxxx"
}
```

### Paso 7: Verificar en Snowflake

Abre Snowflake Web UI o usa SnowSQL:

```sql
```sql
USE ROLE ACCOUNTADMIN;
USE DATABASE DEMO_KMS_V3;

-- Verificar Storage Integration
DESC INTEGRATION S3_INTEGRATION_KMS;

-- Listar archivos
LIST @S3_STAGE_KMS;
```

Deberías ver `test.csv` en la lista.

### Paso 8: Test de Carga

```sql
-- Crear tabla
CREATE OR REPLACE TABLE test_load (
    id INTEGER,
    name VARCHAR,
    value INTEGER
);

-- Cargar datos
COPY INTO test_load
FROM @S3_STAGE_KMS/test.csv
FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1);

-- Verificar
SELECT * FROM test_load;
```

Deberías ver:
```
ID | NAME  | VALUE
1  | test1 | 100
2  | test2 | 200
```

## ✅ Checklist de Verificación

- [ ] Terraform init exitoso
- [ ] Terraform apply completado sin errores
- [ ] KMS key creada con alias
- [ ] S3 bucket con encriptación KMS
- [ ] Bucket key habilitado
- [ ] IAM role creado
- [ ] Storage Integration en Snowflake
- [ ] Stage funcional
- [ ] Test de subida a S3 exitoso
- [ ] Archivo encriptado con KMS
- [ ] Test de carga en Snowflake exitoso

## 🚨 Si algo falla

### Error: "Bucket name already exists"

```bash
# Cambiar nombre del bucket en terraform.tfvars
s3_bucket_name = "s3-snow-kms-test-v3-TU-NOMBRE"

# Aplicar de nuevo
terraform apply
```

### Error: "Database already exists"

```bash
# Cambiar nombre en terraform.tfvars
snowflake_database = "DEMO_KMS_V3"

# Aplicar de nuevo
terraform apply
```

### Error: "Access Denied - KMS"

```bash
# Verificar que el IAM role tiene permisos
aws iam get-role-policy \
  --role-name snowflake-s3-kms-role \
  --policy-name snowflake-s3-kms-s3-kms-policy

# Re-aplicar para actualizar políticas
terraform apply -target=aws_kms_key_policy.snowflake_s3 -auto-approve
```

### Error: Dependencias Circulares

```bash
# Usar despliegue en fases (Opción A arriba)
# O usar el script:
./commands.sh
# Selecciona opción 4
```

## 🔄 Actualizar el Proyecto

Si necesitas hacer cambios:

```bash
# 1. Editar terraform.tfvars o archivos .tf
nano terraform.tfvars

# 2. Ver cambios
terraform plan

# 3. Aplicar
terraform apply
```

## 🗑️ Limpiar Todo

```bash
# Ver qué se eliminará
terraform plan -destroy

# Confirmar y destruir
terraform destroy
# Escribe: yes
```

## 📝 Siguiente Pasos

1. **Revisa los outputs detallados:**
   ```bash
   terraform output quick_reference
   terraform output verification_commands
   ```

2. **Prueba el script SQL completo:**
   ```bash
   # En Snowflake Web UI, copia y pega:
   cat test_snowflake.sql
   ```

3. **Monitorea costos de KMS:**
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/KMS \
     --metric-name NumberOfRequests \
     --dimensions Name=KeyId,Value=$(terraform output -raw kms_key_id) \
     --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 3600 \
     --statistics Sum
   ```

## 🎓 Aprende Más

- Lee el `README.md` completo para detalles
- Revisa `test_snowflake.sql` para pruebas avanzadas
- Consulta los comentarios en archivos `.tf` para entender cada recurso

## 💡 Tips

- **Bucket Key** está habilitado = costos de KMS reducidos ~99%
- **KMS Rotation** está activa = mejor seguridad
- **Versioning** en S3 = protección contra eliminación accidental
- **External ID** en IAM = protección contra confused deputy attack

---

**¿Todo funcionando?** 🎉 ¡Felicidades! Ahora tienes una integración segura S3-Snowflake con KMS.

**¿Problemas?** Revisa la sección "Solución de Problemas" en `README.md`.
