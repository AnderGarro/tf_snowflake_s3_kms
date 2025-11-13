# Terraform S3-Snowflake Integration with KMS Encryption

This project implements a complete integration between AWS S3 and Snowflake using **KMS encryption** for maximum data security.

## 📋 Features

- ✅ **KMS Encryption**: S3 bucket encrypted with AWS KMS
- ✅ **S3 Bucket Key**: Reduces KMS costs by ~99%
- ✅ **Automatic rotation**: KMS key rotation enabled
- ✅ **Secure IAM**: Minimum necessary permissions with External ID
- ✅ **Storage Integration**: Native Snowflake-S3 integration with KMS
- ✅ **External Stage**: Stage configured for data loading
- ✅ **Lifecycle policies**: Automatic management of versions and old files
- ✅ **Public blocking**: Completely private bucket

## 🏗️ Architecture

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

## 📦 Project Structure

```
terraform-s3-snowflake-kms/
├── providers.tf           # AWS and Snowflake providers configuration
├── variables.tf           # Variable definitions
├── outputs.tf             # Outputs with useful information
├── main.tf                # Main orchestration
├── kms.tf                 # KMS key, alias and policies
├── s3.tf                  # S3 bucket with KMS encryption
├── iam.tf                 # IAM role and policies for Snowflake
├── snowflake.tf           # Database, schema, storage integration and stage
├── terraform.tfvars.example  # Variables template
├── .gitignore             # Files to ignore in git
└── README.md              # This file
```

## 🚀 Quick Start

### Prerequisites

1. **Terraform** >= 1.0
2. **AWS CLI** configured
3. **Snowflake account** with ACCOUNTADMIN permissions
4. **AWS credentials** with permissions to create:
   - KMS keys
   - S3 buckets
   - IAM roles and policies

### Step 1: Clone and Configure

```bash
# Navigate to directory
cd terraform-s3-snowflake-kms

# Copy variables file
cp terraform.tfvars.example terraform.tfvars

# Edit with your credentials
nano terraform.tfvars
```

### Step 2: Configure Variables

Edit `terraform.tfvars` with your values:

```hcl
# AWS
aws_access_key = "YOUR_AWS_ACCESS_KEY"
aws_secret_key = "YOUR_AWS_SECRET_KEY"
aws_account_id = "YOUR_ACCOUNT_ID"

# Snowflake
snowflake_user     = "YOUR_USER"
snowflake_password = "YOUR_PASSWORD"
snowflake_account  = "YOUR_ACCOUNT"

# S3
s3_bucket_name = "my-unique-kms-bucket"  # Must be globally unique
```

### Step 3: Deploy

```bash
# Initialize Terraform
terraform init

# View execution plan
terraform plan

# Apply changes
terraform apply
```

⚠️ **Important**: Deployment may take 5-10 minutes due to dependencies between resources.

## 🔄 Automatic Deployment Process

This project automatically manages circular dependencies between AWS and Snowflake using a two-phase approach:

### Phase 1: Base Resources
1. ✅ Create KMS key with dynamic policy
2. ✅ Create S3 bucket with KMS encryption
3. ✅ Create IAM role with temporary trust policy

### Phase 2: Automatic Update
1. ✅ Create Storage Integration in Snowflake (generates External ID)
2. ✅ `null_resource` automatically updates IAM role trust policy with:
   - Correct Snowflake IAM User ARN
   - Storage Integration External ID
3. ✅ Create External Stage

**Note**: The process is completely automatic. The `null_resource` in `iam_updated.tf` executes `aws iam update-assume-role-policy` to update the trust policy after the Storage Integration is created.

## 📊 Important Outputs

After deployment, you'll get:

```bash
# View all outputs
terraform output

# Specific outputs
terraform output kms_key_arn
terraform output s3_bucket_name
terraform output snowflake_iam_user_arn
```

### Key Outputs:

- **kms_key_arn**: KMS key ARN for encryption
- **kms_key_alias**: Friendly alias (alias/snowflake-s3-kms-stage)
- **s3_bucket_name**: Created bucket name
- **iam_role_arn**: Snowflake role ARN
- **snowflake_iam_user_arn**: Snowflake IAM user (critical)
- **snowflake_external_id**: External ID for trust policy

## 🔍 Post-Deployment Verification

### 1. Verify KMS Key

```bash
# Describe the key
aws kms describe-key --key-id alias/snowflake-s3-kms-stage --region eu-west-1

# View policy
aws kms get-key-policy \
  --key-id alias/snowflake-s3-kms-stage \
  --policy-name default \
  --region eu-west-1
```

### 2. Verify S3 Encryption

```bash
# View encryption configuration
aws s3api get-bucket-encryption --bucket <your-bucket>

# Should display:
# "SSEAlgorithm": "aws:kms"
# "KMSMasterKeyID": "arn:aws:kms:..."
# "BucketKeyEnabled": true
```

### 3. File Upload Test

```bash
# Create test file
echo "col1,col2\nvalue1,value2" > test.csv

# Upload to S3
aws s3 cp test.csv s3://<your-bucket>/snowflake-data/

# Verify object encryption
aws s3api head-object \
  --bucket <your-bucket> \
  --key snowflake-data/test.csv \
  --query 'ServerSideEncryption,SSEKMSKeyId'

# Should return:
# "ServerSideEncryption": "aws:kms"
# "SSEKMSKeyId": "arn:aws:kms:eu-west-1:..."
```

### 4. Verify in Snowflake

```sql
-- Connect to Snowflake
USE ROLE ACCOUNTADMIN;
USE DATABASE DEMO_KMS_V3;
USE SCHEMA DEMO_SCHEMA;

-- Verify Storage Integration
DESC INTEGRATION S3_INTEGRATION_KMS;

-- View encryption configuration
SHOW PARAMETERS LIKE 'ENCRYPTION%' IN INTEGRATION S3_INTEGRATION_KMS;

-- List files in stage
LIST @S3_STAGE_KMS;

-- Load test
CREATE OR REPLACE TABLE test_kms (
  col1 VARCHAR,
  col2 VARCHAR
);

COPY INTO test_kms
FROM @S3_STAGE_KMS
FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1);

SELECT * FROM test_kms;
```

## 💰 Cost Considerations

### KMS Pricing (eu-west-1)

| Concept | Cost |
|----------|-------|
| Key storage | ~$1/month per key |
| API requests | $0.03 per 10,000 requests |

### 🎯 Optimization: S3 Bucket Key

✅ **Enabled by default** in this project

- Reduces KMS requests by ~99%
- Significant savings in buckets with many objects

**Savings example:**
- Without Bucket Key: 1M objects = $3,000/month in KMS
- With Bucket Key: 1M objects = ~$30/month in KMS

## 🔐 Security

### Implemented Security Features:

1. **KMS Key Rotation**: Automatic annual rotation
2. **External ID**: Prevents confused deputy attack
3. **Least Privilege**: Minimum necessary IAM permissions
4. **Condition Keys**: KMS only via S3 service
5. **Public Block**: Completely private bucket
6. **Versioning**: Protection against accidental deletion
7. **Bucket Policy**: Restriction to specific IAM role

### KMS Key Policies:

The KMS key allows:
- ✅ Root account: Full administration
- ✅ S3 service: Encrypt/Decrypt for the bucket
- ✅ Snowflake IAM Role: Decrypt via S3
- ✅ Snowflake IAM User: Decrypt via S3

## 🚨 Troubleshooting

### Error: "Access Denied - KMS"

**Cause**: Snowflake cannot use the KMS key

**Solution**:
```bash
# Verify KMS policy
aws kms get-key-policy --key-id alias/snowflake-s3-kms-stage --policy-name default

# Verify it includes the Snowflake IAM User ARN
terraform output snowflake_iam_user_arn
```

### Error: "The ciphertext refers to a customer master key that does not exist"

**Cause**: Incorrect KMS key ARN in Storage Integration

**Solution**:
```sql
-- Verify in Snowflake
DESC INTEGRATION S3_INTEGRATION_KMS;

-- Re-apply Terraform
terraform apply -refresh-only
terraform apply
```

### Error: Incorrect Trust Policy

**Cause**: IAM role has an old or incorrect External ID

**Solution**:
```bash
# null_resource should automatically update the trust policy
# If it doesn't work, run manually:
terraform taint null_resource.update_iam_trust_policy
terraform apply

# Or verify the correct External ID:
terraform output snowflake_external_id
```

### Note on Circular Dependencies

✅ **This problem is automatically resolved** by the project using `null_resource`.

The two-phase approach handles the circular dependency:
1. IAM role is created with temporary trust policy
2. Storage Integration is created and generates External ID
3. `null_resource` automatically updates the trust policy with correct values

No manual intervention needed.

## 🔄 Project Updates

### Change bucket name:

```bash
# Edit terraform.tfvars
s3_bucket_name = "new-bucket-name"

# Apply (will create new bucket, old one must be deleted manually)
terraform apply
```

### Change region:

```bash
# Edit terraform.tfvars
aws_region = "us-east-1"

# Destroy existing resources
terraform destroy

# Recreate in new region
terraform apply
```

## 🗑️ Cleanup

To destroy all resources:

```bash
# View what will be destroyed
terraform plan -destroy

# Destroy everything
terraform destroy

# Confirm with: yes
```

⚠️ **Warning**: 
- KMS key will enter deletion period (10 days by default)
- S3 objects will be permanently deleted
- Storage Integration in Snowflake will be deleted

## 📚 References

- [Snowflake: Using AWS KMS](https://docs.snowflake.com/en/user-guide/data-load-s3-kms)
- [AWS KMS Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
- [S3 Bucket Keys](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-key.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Snowflake Provider](https://registry.terraform.io/providers/Snowflake-Labs/snowflake/latest/docs)

## 🤝 Support

If you encounter problems:

1. Check Terraform logs: `terraform show`
2. Review outputs: `terraform output`
3. Consult the troubleshooting section
4. Verify IAM and KMS policies manually

## 📝 Important Notes

- ⚠️ **Sensitive credentials**: Never commit `terraform.tfvars`
- ⚠️ **State file**: The `.tfstate` file contains sensitive information
- ⚠️ **KMS deletion**: Keys have a waiting period before deletion
- ⚠️ **Costs**: Monitor KMS API calls usage
- ✅ **Bucket Key**: Already enabled to reduce costs
- ✅ **Automatic rotation**: KMS key rotates annually

## ✅ Implementation Checklist

- [x] Create KMS key with automatic rotation
- [x] Configure KMS key policy
- [x] Update S3 encryption to aws:kms
- [x] Enable S3 Bucket Key to reduce costs
- [x] Add KMS permissions to Snowflake IAM role
- [x] Configure Storage Integration with KMS
- [x] Create External Stage
- [x] Document verification process
- [ ] Complete data load test
- [ ] Configure CloudTrail to audit KMS (optional)
- [ ] Implement CloudWatch alarms (optional)

## 📊 Recommended Next Steps

1. **Configure CloudTrail** to audit KMS access:
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

2. **Configure CloudWatch Alarms** for KMS failures
3. **Implement additional Tags** for cost allocation
4. **Configure backup** of state file in S3 backend

---

**Version**: 1.0  
**Last updated**: November 2025  
**Author**: Terraform S3-Snowflake-KMS Integration Project
