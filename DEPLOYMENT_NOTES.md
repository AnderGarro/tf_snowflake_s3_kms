# Deployment Notes - S3-Snowflake-KMS Integration

## ✅ Current Status

**Version**: V3  
**S3 Bucket**: `s3-snow-kms-test-v3`  
**Snowflake Database**: `DEMO_KMS_V3`  
**Last updated**: November 13, 2025

---

## 🔧 Implemented Approach

### Circular Dependency Management

The project uses an **automatic two-phase approach** to resolve the circular dependency between IAM Role and Storage Integration:

#### Key Files:
- **`iam.tf`**: Defines IAM role with initial temporary trust policy
- **`iam_updated.tf`**: Contains `null_resource` that automatically updates the trust policy

#### Flow:
1. **Phase 1**: Create base resources (KMS, S3, IAM role with temporary trust)
2. **Storage Integration**: Snowflake creates integration and generates External ID
3. **Phase 2**: `null_resource` automatically executes `aws iam update-assume-role-policy`
4. **Result**: Trust policy updated with correct External ID

### Terraform Command:
```bash
terraform init
terraform apply  # Everything automatic
```

---

## 📁 File Structure

### Terraform Core
- `providers.tf` - Providers configuration (AWS, Snowflake, null)
- `variables.tf` - Input variables
- `terraform.tfvars` - Current values (not committed)
- `terraform.tfvars.example` - Example template
- `outputs.tf` - Deployment outputs

### AWS Resources
- `kms.tf` - KMS key with automatic rotation
- `s3.tf` - S3 bucket with KMS encryption and Bucket Key
- `iam.tf` - IAM role with initial trust policy
- `iam_updated.tf` - ⭐ Automatic trust policy update

### Snowflake Resources
- `snowflake.tf` - Database, Schema, Storage Integration and Stage
- `main.tf` - Main orchestration

### Documentation
- `README.md` - Complete documentation
- `QUICKSTART.md` - Quick start guide
- `ARCHITECTURE.md` - Diagrams and architecture
- `DEPLOYMENT_NOTES.md` - This file

### Scripts and Tests
- `commands.sh` - Interactive script with useful commands
- `test_snowflake.sql` - Complete SQL tests
- `test_snowflake_connection.sql` - Quick connection test
- `test_data.csv` - Test data

---

## 🔑 Current Configuration

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

## 🧪 Quick Verification

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

-- View Storage Integration
DESC INTEGRATION S3_INTEGRATION_KMS;

-- List files
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

✅ **Automatically resolved** by `null_resource.update_iam_trust_policy`

If it persists:
```bash
# Force trust policy update
terraform taint null_resource.update_iam_trust_policy
terraform apply
```

### Error: "Access Denied - KMS"

Verify that the KMS key policy includes the Snowflake IAM User:
```bash
aws kms get-key-policy \
  --key-id alias/snowflake-s3-kms-stage \
  --policy-name default \
  --region eu-west-1
```

### Verify Complete State

```bash
# View all outputs
terraform output

# View resource state
terraform state list

# Verify null_resource
terraform state show null_resource.update_iam_trust_policy
```

---

## 📝 Maintenance

### Update Trust Policy Manually (if needed)

```bash
# Get current values
EXTERNAL_ID=$(terraform output -raw snowflake_external_id)
IAM_USER=$(terraform output -raw snowflake_iam_user_arn)

# Update
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

### Recreate Storage Integration

If you need to recreate the Storage Integration:
```bash
# Delete
terraform destroy -target=snowflake_stage.s3_stage
terraform destroy -target=snowflake_storage_integration.s3_integration_kms

# Recreate
terraform apply
```

### Change to New Bucket

```bash
# Edit terraform.tfvars
s3_bucket_name = "s3-snow-kms-test-v4"

# Apply
terraform apply

# null_resource will execute automatically
```

---

## 💡 Best Practices

1. **Always run `terraform plan` before `apply`**
2. **The `null_resource` executes automatically when these change**:
   - Storage Integration External ID
   - Storage Integration IAM User ARN
   - IAM Role name
3. **Don't delete `iam_updated.tf`** - it's critical for automatic management
4. **Use `terraform refresh`** after manual changes in AWS/Snowflake
5. **Keep `terraform.tfvars` out of git** (already in .gitignore)

---

## 🔗 References

- **README.md** - Complete project documentation
- **QUICKSTART.md** - 5-minute quick start
- **ARCHITECTURE.md** - Detailed architecture diagrams
- **commands.sh** - 13 useful interactive commands

---

**Última verificación**: 13 noviembre 2025  
**Estado**: ✅ Funcionando correctamente  
**Approach**: Dependencias circulares resueltas automáticamente
