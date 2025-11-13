# Terraform S3-Snowflake Integration with KMS Encryption

[![Terraform](https://img.shields.io/badge/Terraform-≥1.0-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-KMS%20%7C%20S3%20%7C%20IAM-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![Snowflake](https://img.shields.io/badge/Snowflake-Storage%20Integration-29B5E8?logo=snowflake)](https://www.snowflake.com/)

Complete and secure Terraform project that implements integration between **AWS S3** and **Snowflake** using **KMS encryption** for maximum data protection.

## 🌟 Features

- ✅ **KMS Encryption**: S3 bucket encrypted with AWS KMS and automatic key rotation
- ✅ **S3 Bucket Key**: KMS cost optimization (~99% reduction)
- ✅ **Secure IAM**: Least privilege permissions with External ID
- ✅ **Automatic Management**: Circular dependencies resolved automatically
- ✅ **Storage Integration**: Native Snowflake-S3 integration with KMS
- ✅ **External Stage**: Stage configured for data loading and unloading
- ✅ **Lifecycle Policies**: Automatic management of versions and old files
- ✅ **Total Security**: Fully private bucket with multiple security layers

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
s3_bucket_name = "my-unique-bucket"  # Must be globally unique

# Snowflake
snowflake_account  = "TU_ACCOUNT"
snowflake_user     = "YOUR_USER"
snowflake_password = "YOUR_PASSWORD"
snowflake_database = "DEMO_KMS_V3"
```

## 📁 Project Structure

```
tf_snowflake_s3_kms/
├── providers.tf          # Providers configuration (AWS, Snowflake, null)
├── variables.tf          # Input variables
├── main.tf               # Main orchestration
├── kms.tf                # KMS key with automatic rotation
├── s3.tf                 # S3 bucket with KMS encryption
├── iam.tf                # IAM role with initial trust policy
├── iam_updated.tf        # ⭐ Auto-update trust policy
├── snowflake.tf          # Database, schema, storage integration, stage
├── outputs.tf            # Deployment outputs
│
├── README.md             # Complete documentation
├── QUICKSTART.md         # Quick start guide
├── ARCHITECTURE.md       # Detailed diagrams
├── DEPLOYMENT_NOTES.md   # Technical notes
│
├── commands.sh           # Interactive script with useful commands
├── test_snowflake.sql    # Complete SQL tests
└── test_snowflake_connection.sql  # Quick test
```

## 🔐 Security

### Implemented Features

- **KMS Key Rotation**: Automatic annual key rotation
- **External ID**: Prevents confused deputy attacks
- **Least Privilege**: Minimum necessary IAM permissions
- **Condition Keys**: KMS only via S3 service (`kms:ViaService`)
- **Public Block**: Completely private bucket
- **Versioning**: Protection against accidental deletion
- **Bucket Policy**: Restriction to specific IAM role
- **Multi-layer Security**: 5 security layers (see `ARCHITECTURE.md`)

### Protected Sensitive Data

The `.gitignore` automatically excludes:
- `*.tfvars` (credentials)
- `*.tfstate` (resource information)
- Test files with real data
- Backups and temporary files

## 🧪 Post-Deployment Verification

### AWS

```bash
# Verify KMS
aws kms describe-key --key-id alias/snowflake-s3-kms-stage --region eu-west-1

# Verify S3 encryption
terraform output s3_bucket_name | xargs -I {} aws s3api get-bucket-encryption --bucket {}

# Upload test
aws s3 cp test.csv s3://$(terraform output -raw s3_bucket_name)/snowflake-data/
```

### Snowflake

```sql
USE ROLE ACCOUNTADMIN;
USE DATABASE DEMO_KMS_V3;
USE SCHEMA DEMO_SCHEMA;

-- Verify Storage Integration
DESC INTEGRATION S3_INTEGRATION_KMS;

-- List files
LIST @S3_STAGE_KMS;

-- Load test
CREATE TABLE test_load (col1 STRING, col2 STRING);
COPY INTO test_load FROM @S3_STAGE_KMS FILE_FORMAT = (TYPE = CSV);
SELECT * FROM test_load;
```

## 💰 Cost Optimization

### S3 Bucket Key Enabled

- ✅ Reduces KMS API calls by ~99%
- ✅ No security impact
- ✅ Significant savings:
  - **Without Bucket Key**: 1M objects = ~$3,000/month
  - **With Bucket Key**: 1M objects = ~$30/month

### Lifecycle Policies

- Transition to IA after 30 days
- Transition to Glacier after 90 days
- Automatic deletion of old versions

## 📊 Main Outputs

After deployment:

```bash
terraform output

# Outputs include:
# - kms_key_arn: KMS key ARN
# - s3_bucket_name: Created bucket name
# - iam_role_arn: Snowflake role ARN
# - snowflake_iam_user_arn: Snowflake IAM user
# - snowflake_external_id: External ID for trust policy
# - verification_commands: Commands to verify deployment
```

## 🔄 Updates

```bash
# Change configuration in terraform.tfvars
nano terraform.tfvars

# View changes
terraform plan

# Apply
terraform apply

# null_resource will automatically update trust policy if needed
```

## 🗑️ Cleanup

```bash
# Destroy all resources
terraform destroy

# ⚠️ Warning: 
# - KMS key will enter deletion period (10 days)
# - S3 objects will be permanently deleted
```

## 🚨 Troubleshooting

### Error: "Could not assume role"

✅ **Automatically resolved** by `null_resource.update_iam_trust_policy`

If it persists:
```bash
terraform taint null_resource.update_iam_trust_policy
terraform apply
```

### Error: "Access Denied - KMS"

Verify KMS policy:
```bash
aws kms get-key-policy --key-id alias/snowflake-s3-kms-stage --policy-name default
```

See more solutions in `README.md` and `DEPLOYMENT_NOTES.md`.

## 📚 Documentation

- **[README.md](README.md)** - Complete project documentation
- **[QUICKSTART.md](QUICKSTART.md)** - 5-minute quick start guide
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Detailed diagrams and architecture
- **[DEPLOYMENT_NOTES.md](DEPLOYMENT_NOTES.md)** - Technical notes and approach

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the project
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License. See `LICENSE` for more information.

## 🔗 References

- [Snowflake: Using AWS KMS](https://docs.snowflake.com/en/user-guide/data-load-s3-kms)
- [AWS KMS Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
- [S3 Bucket Keys](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-key.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Snowflake Provider](https://registry.terraform.io/providers/Snowflake-Labs/snowflake/latest/docs)

## ⭐ Acknowledgments

If this project was useful to you, consider giving it a star ⭐ on GitHub!

---

**Author**: Ander Garro  
**Last updated**: November 2025  
**Version**: 1.0
