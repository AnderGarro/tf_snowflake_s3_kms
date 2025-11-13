# Snowflake Database
resource "snowflake_database" "demo" {
  name                        = var.snowflake_database
  comment                     = "Database for S3-KMS integration demo"
  data_retention_time_in_days = 1
  is_transient                = false
}

# Snowflake Schema
resource "snowflake_schema" "demo" {
  database            = snowflake_database.demo.name
  name                = var.snowflake_schema
  comment             = "Schema for S3-KMS stage"
  is_transient        = false
  with_managed_access = false
}

# Snowflake Storage Integration with KMS encryption
resource "snowflake_storage_integration" "s3_integration_kms" {
  name    = var.storage_integration_name
  comment = "Storage integration with AWS S3 and KMS encryption"
  type    = "EXTERNAL_STAGE"

  enabled = true

  storage_allowed_locations = [
    "s3://${aws_s3_bucket.snowflake_stage.bucket}/${var.s3_prefix}"
  ]

  storage_provider = "S3"

  storage_aws_role_arn = aws_iam_role.snowflake_role.arn

  # Dependencies are automatic from attribute references above
}

# Note: KMS encryption is configured at the S3 bucket level
# Snowflake will automatically use the bucket's KMS encryption settings
# when accessing objects through the storage integration

# Snowflake External Stage using the storage integration
resource "snowflake_stage" "s3_stage" {
  name                = var.stage_name
  database            = snowflake_database.demo.name
  schema              = snowflake_schema.demo.name
  storage_integration = snowflake_storage_integration.s3_integration_kms.name
  url                 = "s3://${aws_s3_bucket.snowflake_stage.bucket}/${var.s3_prefix}"
  comment             = "External stage with KMS encrypted S3 bucket"

  depends_on = [
    snowflake_storage_integration.s3_integration_kms
  ]
}

# Note: Grants are managed manually or through Snowflake RBAC
# Modern Snowflake provider uses grant resources differently
# You can grant permissions manually in Snowflake:
# GRANT USAGE ON DATABASE DEMO_KMS_V3 TO ROLE ACCOUNTADMIN;
# GRANT USAGE ON SCHEMA DEMO_KMS_V3.DEMO_SCHEMA TO ROLE ACCOUNTADMIN;
# GRANT USAGE ON INTEGRATION S3_INTEGRATION_KMS TO ROLE ACCOUNTADMIN;

