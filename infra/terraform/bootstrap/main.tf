# Remote-state backend bootstrap.
#
# Run this ONCE, with LOCAL state, before the root stack. It creates the S3
# bucket (versioned + encrypted + private) and the DynamoDB lock table that the
# root stack's backend.tf points at. Chicken-and-egg: you can't store the state
# of the thing that creates your state bucket in that same bucket, so this stays
# local. It changes ~never.
#
#   cd infra/terraform/bootstrap
#   terraform init && terraform apply
#   terraform output backend_config   # paste into ../backend.tf if you renamed anything

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name

  # Refuse `terraform destroy` from nuking the state bucket by accident.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = var.state_bucket_name
    Project   = "capstone-phoenix"
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST" # no idle cost; you pay per lock op
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = var.lock_table_name
    Project   = "capstone-phoenix"
    ManagedBy = "Terraform"
  }
}
