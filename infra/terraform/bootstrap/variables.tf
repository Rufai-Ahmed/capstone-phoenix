variable "aws_region" {
  description = "AWS region for the remote-state bucket and lock table."
  type        = string
  default     = "eu-north-1"
}

variable "state_bucket_name" {
  description = "Globally-unique S3 bucket name for Terraform remote state."
  type        = string
  default     = "capstone-phoenix-tfstate"
}

variable "lock_table_name" {
  description = "DynamoDB table name for Terraform state locking."
  type        = string
  default     = "capstone-phoenix-tflock"
}
