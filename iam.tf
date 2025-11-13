# IAM Role for Snowflake to access S3
resource "aws_iam_role" "snowflake_role" {
  name               = "${var.project_name}-role"
  description        = "IAM role for Snowflake to access S3 bucket with KMS encryption"
  assume_role_policy = data.aws_iam_policy_document.snowflake_trust_policy.json

  tags = {
    Name        = "${var.project_name}-role"
    Environment = var.environment
    Purpose     = "Snowflake S3 access with KMS"
  }
}

# Trust policy allowing Snowflake to assume the role
# Initial trust policy with temporary values to break circular dependency
# Will be updated by null_resource after storage integration is created
data "aws_iam_policy_document" "snowflake_trust_policy" {
  statement {
    effect = "Allow"

    principals {
      type = "AWS"
      # Initial placeholder - will be updated after storage integration creation
      identifiers = ["arn:aws:iam::260512157176:user/5c391000-s"]
    }

    actions = ["sts:AssumeRole"]

    # External ID for security (prevents confused deputy problem)
    # Initial placeholder - will be updated after storage integration creation
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = ["TEMP_INITIAL_EXTERNAL_ID"]
    }
  }
}

# IAM Policy for S3 and KMS access
data "aws_iam_policy_document" "snowflake_s3_kms_access" {
  # S3 Object operations
  statement {
    sid = "SnowflakeS3ObjectAccess"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      "${aws_s3_bucket.snowflake_stage.arn}/*"
    ]
  }

  # S3 Bucket operations
  statement {
    sid = "SnowflakeS3BucketAccess"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]

    resources = [
      aws_s3_bucket.snowflake_stage.arn
    ]

    # Optional: Restrict to specific prefix
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        "${var.s3_prefix}*",
        ""
      ]
    }
  }

  # KMS operations
  statement {
    sid = "SnowflakeKMSAccess"

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey",
      "kms:Encrypt"
    ]

    resources = [
      aws_kms_key.snowflake_s3.arn
    ]

    # Ensure KMS is only used via S3
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values = [
        "s3.${var.aws_region}.amazonaws.com"
      ]
    }
  }
}

# Attach policy to role
resource "aws_iam_role_policy" "snowflake_s3_kms_access" {
  name   = "${var.project_name}-s3-kms-policy"
  role   = aws_iam_role.snowflake_role.id
  policy = data.aws_iam_policy_document.snowflake_s3_kms_access.json
}

# Optional: Attach AWS managed policy for S3 read-only (if needed for additional operations)
# resource "aws_iam_role_policy_attachment" "s3_read_only" {
#   role       = aws_iam_role.snowflake_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
# }
