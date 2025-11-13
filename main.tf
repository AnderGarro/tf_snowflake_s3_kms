# Main Terraform configuration for S3-Snowflake-KMS integration
# This file orchestrates the creation of all resources

# Data source to get current AWS caller identity
data "aws_caller_identity" "current" {}

# Outputs for verification
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    aws_region           = var.aws_region
    s3_bucket           = aws_s3_bucket.snowflake_stage.id
    kms_key_id          = aws_kms_key.snowflake_s3.key_id
    iam_role_arn        = aws_iam_role.snowflake_role.arn
    storage_integration = snowflake_storage_integration.s3_integration_kms.name
    stage               = snowflake_stage.s3_stage.name
  }
}
