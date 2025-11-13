# KMS Key for S3 bucket encryption
resource "aws_kms_key" "snowflake_s3" {
  description             = "KMS key for Snowflake S3 bucket encryption"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = var.enable_kms_key_rotation

  tags = {
    Name        = "${var.project_name}-kms-key"
    Environment = var.environment
    Purpose     = "S3 encryption for Snowflake integration"
  }
}

# KMS Key Alias for easy reference
resource "aws_kms_alias" "snowflake_s3" {
  name          = "alias/${var.project_name}-stage"
  target_key_id = aws_kms_key.snowflake_s3.key_id
}

# KMS Key Policy
# This policy allows:
# 1. Root account to manage the key
# 2. S3 service to use the key for encryption/decryption
# 3. Snowflake IAM user to decrypt objects (added after storage integration is created)
resource "aws_kms_key_policy" "snowflake_s3" {
  key_id = aws_kms_key.snowflake_s3.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 to use the key"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Snowflake IAM Role to use the key"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.snowflake_role.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })
}
