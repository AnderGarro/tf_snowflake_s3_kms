# AWS Variables
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-west-1"
}

variable "aws_access_key" {
  description = "AWS access key"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS secret key"
  type        = string
  sensitive   = true
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

# S3 Variables
variable "s3_bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "s3_prefix" {
  description = "Prefix path in S3 bucket for Snowflake data"
  type        = string
  default     = "snowflake-data/"
}

# KMS Variables
variable "enable_kms_encryption" {
  description = "Enable KMS encryption for S3 bucket"
  type        = bool
  default     = true
}

variable "kms_key_deletion_window" {
  description = "Days before KMS key deletion (7-30)"
  type        = number
  default     = 10
}

variable "enable_kms_key_rotation" {
  description = "Enable automatic KMS key rotation"
  type        = bool
  default     = true
}

# Snowflake Variables
variable "snowflake_account" {
  description = "Snowflake account identifier"
  type        = string
}

variable "snowflake_user" {
  description = "Snowflake username"
  type        = string
  sensitive   = true
}

variable "snowflake_password" {
  description = "Snowflake password"
  type        = string
  sensitive   = true
}

variable "snowflake_role" {
  description = "Snowflake role to use"
  type        = string
  default     = "ACCOUNTADMIN"
}

variable "snowflake_database" {
  description = "Snowflake database name"
  type        = string
}

variable "snowflake_schema" {
  description = "Snowflake schema name"
  type        = string
  default     = "PUBLIC"
}

variable "storage_integration_name" {
  description = "Name of the Snowflake storage integration"
  type        = string
  default     = "S3_INTEGRATION_KMS"
}

variable "stage_name" {
  description = "Name of the Snowflake stage"
  type        = string
  default     = "S3_STAGE_KMS"
}

# General Variables
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "snowflake-s3-kms"
}
