# Quick Start Guide - Terraform S3-Snowflake-KMS

## 🚀 5-Minute Deployment

### Step 1: Verify Prerequisites

```bash
# Verify Terraform
terraform version
# Should show: Terraform v1.0+

# Verify AWS CLI
aws --version
aws sts get-caller-identity
# Should show your Account ID: 997439898896

# Verify credentials
cat terraform.tfvars | grep -v "password\|secret"
```

### Step 2: Initialize

```bash
terraform init
```

You should see:
```
Terraform has been successfully initialized!
```

### Step 3: Deploy (Recommended Option)

**Option A - Phased Deployment (Recommended):**

```bash
# Phase 1: KMS
terraform apply -target=aws_kms_key.snowflake_s3 -target=aws_kms_alias.snowflake_s3 -auto-approve

# Phase 2: S3
terraform apply -target=aws_s3_bucket.snowflake_stage -auto-approve

# Phase 3: IAM
terraform apply -target=aws_iam_role.snowflake_role -auto-approve

# Phase 4: Snowflake Database and Schema
terraform apply -target=snowflake_database.demo -target=snowflake_schema.demo -auto-approve

# Phase 5: Storage Integration
terraform apply -target=snowflake_storage_integration.s3_integration_kms -auto-approve

# Phase 6: Complete everything
terraform apply -auto-approve
```

**Option B - Full Deployment:**

```bash
terraform apply
# Type: yes
```

**Option C - Use Interactive Script:**

```bash
./commands.sh
# Select option 4: "Apply in phases"
```

### Step 4: Verify Outputs

```bash
terraform output
```

You should see something like:

```
kms_key_arn = "arn:aws:kms:eu-west-1:997439898896:key/xxxx-xxxx-xxxx"
kms_key_alias = "alias/snowflake-s3-kms-stage"
```bash
# S3 Bucket name (must be globally unique)
s3_bucket_name = "s3-snow-kms-test-v3"
iam_role_arn = "arn:aws:iam::997439898896:role/snowflake-s3-kms-role"
snowflake_iam_user_arn = "arn:aws:iam::260512157176:user/xxxx"
```

### Step 5: Verify in AWS

```bash
# Verify KMS
aws kms describe-key --key-id alias/snowflake-s3-kms-stage --region eu-west-1

# Verify S3 encryption
aws s3api get-bucket-encryption --bucket s3-snow-kms-test-v3
```

You should see:
```json
{
    "SSEAlgorithm": "aws:kms",
    "KMSMasterKeyID": "arn:aws:kms:eu-west-1:...",
    "BucketKeyEnabled": true
}
```

### Step 6: Upload Test

```bash
# Create test file
echo "id,name,value
1,test1,100
2,test2,200" > test.csv

# Upload to S3
aws s3 cp test.csv s3://s3-snow-kms-test-v3/snowflake-data/

# Verify encryption
aws s3api head-object \
  --bucket s3-snow-kms-test-v3 \
  --key snowflake-data/test.csv \
  --query '{Encryption: ServerSideEncryption, KMSKeyId: SSEKMSKeyId}'
```

You should see:
```json
{
    "Encryption": "aws:kms",
    "KMSKeyId": "arn:aws:kms:eu-west-1:997439898896:key/xxxx"
}
```

### Step 7: Verify in Snowflake

Open Snowflake Web UI or use SnowSQL:

```sql
```sql
USE ROLE ACCOUNTADMIN;
USE DATABASE DEMO_KMS_V3;

-- Verify Storage Integration
DESC INTEGRATION S3_INTEGRATION_KMS;

-- List files
LIST @S3_STAGE_KMS;
```

You should see `test.csv` in the list.
### Step 8: Load Test

```sql
-- Create table
CREATE OR REPLACE TABLE test_load (
    id INTEGER,
    name VARCHAR,
    value INTEGER
);

-- Load data
COPY INTO test_load
FROM @S3_STAGE_KMS/test.csv
FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1);

-- Verify
SELECT * FROM test_load;
```

You should see:
```
ID | NAME  | VALUE
1  | test1 | 100
2  | test2 | 200
```

## ✅ Verification Checklist

- [ ] Terraform init successful
- [ ] Terraform apply completed without errors
- [ ] KMS key created with alias
- [ ] S3 bucket with KMS encryption
- [ ] Bucket key enabled
- [ ] IAM role created
- [ ] Storage Integration in Snowflake
- [ ] Functional stage
- [ ] S3 upload test successful
- [ ] File encrypted with KMS
- [ ] Snowflake load test successful

## 🚨 If Something Fails

### Error: "Bucket name already exists"

```bash
# Change bucket name in terraform.tfvars
s3_bucket_name = "s3-snow-kms-test-v3-YOUR-NAME"

# Apply again
terraform apply
```

### Error: "Database already exists"

```bash
# Change name in terraform.tfvars
snowflake_database = "DEMO_KMS_V3"

# Apply again
terraform apply
```

### Error: "Access Denied - KMS"

```bash
# Verify IAM role has permissions
aws iam get-role-policy \
  --role-name snowflake-s3-kms-role \
  --policy-name snowflake-s3-kms-s3-kms-policy

# Re-apply to update policies
terraform apply -target=aws_kms_key_policy.snowflake_s3 -auto-approve
```

### Error: Circular Dependencies

```bash
# Use phased deployment (Option A above)
# Or use the script:
./commands.sh
# Select option 4
```

## 🔄 Update the Project

If you need to make changes:

```bash
# 1. Edit terraform.tfvars or .tf files
nano terraform.tfvars

# 2. View changes
terraform plan

# 3. Apply
terraform apply
```

## 🗑️ Clean Up Everything

```bash
# View what will be deleted
terraform plan -destroy

# Confirm and destroy
terraform destroy
# Type: yes
```

## 📝 Next Steps

1. **Review detailed outputs:**
   ```bash
   terraform output quick_reference
   terraform output verification_commands
   ```

2. **Test the complete SQL script:**
   ```bash
   # In Snowflake Web UI, copy and paste:
   cat test_snowflake.sql
   ```

3. **Monitor KMS costs:**
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

## 🎓 Learn More

- Read the complete `README.md` for details
- Review `test_snowflake.sql` for advanced tests
- Check comments in `.tf` files to understand each resource

## 💡 Tips

- **Bucket Key** is enabled = KMS costs reduced ~99%
- **KMS Rotation** is active = better security
- **Versioning** in S3 = protection against accidental deletion
- **External ID** in IAM = protection against confused deputy attack

---

**¿Todo funcionando?** 🎉 ¡Felicidades! Ahora tienes una integración segura S3-Snowflake con KMS.

**¿Problemas?** Revisa la sección "Solución de Problemas" en `README.md`.
