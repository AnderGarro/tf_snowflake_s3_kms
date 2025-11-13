terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "~> 0.94"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
  
  # Note: Snowflake provider has moved to snowflakedb/snowflake for Terraform 0.13+
  # Using Snowflake-Labs/snowflake for compatibility
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key

  default_tags {
    tags = {
      Project     = "Snowflake-S3-KMS-Integration"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}

provider "snowflake" {
  account  = var.snowflake_account
  user     = var.snowflake_user
  password = var.snowflake_password
  role     = var.snowflake_role
}
