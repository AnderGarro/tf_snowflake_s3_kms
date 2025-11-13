# S3 Bucket for Snowflake data
resource "aws_s3_bucket" "snowflake_stage" {
  bucket = var.s3_bucket_name

  tags = {
    Name        = var.s3_bucket_name
    Environment = var.environment
    Purpose     = "Snowflake external stage with KMS encryption"
  }
}

# S3 Bucket versioning
resource "aws_s3_bucket_versioning" "snowflake_stage" {
  bucket = aws_s3_bucket.snowflake_stage.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Server-Side Encryption with KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "snowflake_stage" {
  bucket = aws_s3_bucket.snowflake_stage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.snowflake_s3.arn
    }
    # Enable S3 Bucket Key to reduce KMS API costs by ~99%
    bucket_key_enabled = true
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "snowflake_stage" {
  bucket = aws_s3_bucket.snowflake_stage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket lifecycle rule (optional - for data management)
resource "aws_s3_bucket_lifecycle_configuration" "snowflake_stage" {
  bucket = aws_s3_bucket.snowflake_stage.id

  rule {
    id     = "cleanup-old-data"
    status = "Enabled"

    filter {
      prefix = var.s3_prefix
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# S3 Bucket Policy to allow Snowflake access
resource "aws_s3_bucket_policy" "snowflake_stage" {
  bucket = aws_s3_bucket.snowflake_stage.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSnowflakeAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.snowflake_role.arn
        }
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.snowflake_stage.arn}/*"
      },
      {
        Sid    = "AllowSnowflakeListBucket"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.snowflake_role.arn
        }
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = aws_s3_bucket.snowflake_stage.arn
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.snowflake_stage
  ]
}
