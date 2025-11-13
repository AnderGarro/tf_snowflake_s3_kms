# AWS Outputs
output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

# S3 Outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.snowflake_stage.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.snowflake_stage.arn
}

output "s3_bucket_url" {
  description = "Full S3 URL for Snowflake stage"
  value       = "s3://${aws_s3_bucket.snowflake_stage.bucket}/${var.s3_prefix}"
}

# KMS Outputs
output "kms_key_id" {
  description = "ID of the KMS key"
  value       = aws_kms_key.snowflake_s3.key_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key"
  value       = aws_kms_key.snowflake_s3.arn
}

output "kms_key_alias" {
  description = "Alias of the KMS key"
  value       = aws_kms_alias.snowflake_s3.name
}

# IAM Outputs
output "iam_role_name" {
  description = "Name of the IAM role for Snowflake"
  value       = aws_iam_role.snowflake_role.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role for Snowflake"
  value       = aws_iam_role.snowflake_role.arn
}

# Snowflake Outputs
output "snowflake_database" {
  description = "Name of the Snowflake database"
  value       = snowflake_database.demo.name
}

output "snowflake_schema" {
  description = "Name of the Snowflake schema"
  value       = snowflake_schema.demo.name
}

output "storage_integration_name" {
  description = "Name of the Snowflake storage integration"
  value       = snowflake_storage_integration.s3_integration_kms.name
}

output "snowflake_stage_name" {
  description = "Name of the Snowflake stage"
  value       = snowflake_stage.s3_stage.name
}

# Critical Snowflake Integration Details
output "snowflake_iam_user_arn" {
  description = "Snowflake IAM User ARN (use this to update IAM trust policy manually if needed)"
  value       = snowflake_storage_integration.s3_integration_kms.storage_aws_iam_user_arn
  sensitive   = false
}

output "snowflake_external_id" {
  description = "Snowflake External ID (use this to update IAM trust policy manually if needed)"
  value       = snowflake_storage_integration.s3_integration_kms.storage_aws_external_id
  sensitive   = true
}

# Verification Commands
output "verification_commands" {
  description = "Commands to verify the deployment"
  value = {
    check_kms_key = "aws kms describe-key --key-id ${aws_kms_key.snowflake_s3.key_id} --region ${var.aws_region}"
    check_s3_encryption = "aws s3api get-bucket-encryption --bucket ${aws_s3_bucket.snowflake_stage.id}"
    upload_test_file = "aws s3 cp test.csv s3://${aws_s3_bucket.snowflake_stage.bucket}/${var.s3_prefix}"
    check_object_encryption = "aws s3api head-object --bucket ${aws_s3_bucket.snowflake_stage.id} --key ${var.s3_prefix}test.csv --query 'ServerSideEncryption,SSEKMSKeyId'"
  }
}

output "snowflake_commands" {
  description = "Snowflake commands to verify the integration"
  value = {
    describe_integration = "DESC INTEGRATION ${snowflake_storage_integration.s3_integration_kms.name};"
    list_stage_files = "LIST @${snowflake_database.demo.name}.${snowflake_schema.demo.name}.${snowflake_stage.s3_stage.name};"
    test_load = "-- Create a test table and load data\nCREATE OR REPLACE TABLE ${snowflake_database.demo.name}.${snowflake_schema.demo.name}.test_table (col1 STRING, col2 STRING);\nCOPY INTO ${snowflake_database.demo.name}.${snowflake_schema.demo.name}.test_table FROM @${snowflake_database.demo.name}.${snowflake_schema.demo.name}.${snowflake_stage.s3_stage.name} FILE_FORMAT = (TYPE = CSV);"
  }
}

# Quick Reference
output "quick_reference" {
  description = "Quick reference information"
  value = {
    kms_key_id = aws_kms_key.snowflake_s3.key_id
    kms_alias = aws_kms_alias.snowflake_s3.name
    s3_bucket = aws_s3_bucket.snowflake_stage.id
    iam_role = aws_iam_role.snowflake_role.arn
    storage_integration = snowflake_storage_integration.s3_integration_kms.name
    stage = "${snowflake_database.demo.name}.${snowflake_schema.demo.name}.${snowflake_stage.s3_stage.name}"
    encryption = "AWS_SSE_KMS"
    bucket_key_enabled = true
  }
}
