output "state_bucket_name" {
  description = "Name of the S3 bucket holding remote state."
  value       = aws_s3_bucket.state.id
}

output "lock_table_name" {
  description = "Name of the DynamoDB lock table."
  value       = aws_dynamodb_table.lock.id
}

output "backend_config" {
  description = "Paste this into ../backend.tf if you changed any defaults."
  value       = <<-EOT
    bucket         = "${aws_s3_bucket.state.id}"
    key            = "capstone-phoenix/terraform.tfstate"
    region         = "${var.aws_region}"
    dynamodb_table = "${aws_dynamodb_table.lock.id}"
    encrypt        = true
  EOT
}
