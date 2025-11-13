# Updated IAM Role Trust Policy
# This resource updates the IAM role trust policy after storage integration is created

resource "null_resource" "update_iam_trust_policy" {
  # This will trigger whenever the storage integration changes
  triggers = {
    external_id  = snowflake_storage_integration.s3_integration_kms.storage_aws_external_id
    iam_user_arn = snowflake_storage_integration.s3_integration_kms.storage_aws_iam_user_arn
    role_name    = aws_iam_role.snowflake_role.name
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws iam update-assume-role-policy \
        --role-name ${aws_iam_role.snowflake_role.name} \
        --policy-document '{
          "Version": "2012-10-17",
          "Statement": [{
            "Effect": "Allow",
            "Principal": {
              "AWS": "${snowflake_storage_integration.s3_integration_kms.storage_aws_iam_user_arn}"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
              "StringEquals": {
                "sts:ExternalId": "${snowflake_storage_integration.s3_integration_kms.storage_aws_external_id}"
              }
            }
          }]
        }'
    EOT
  }

  depends_on = [
    aws_iam_role.snowflake_role,
    snowflake_storage_integration.s3_integration_kms
  ]
}
