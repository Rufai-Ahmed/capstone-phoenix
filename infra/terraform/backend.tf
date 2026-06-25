# Remote state in S3 with DynamoDB locking. Create these with the bootstrap stack
# FIRST (infra/terraform/bootstrap), then `terraform init` here.
#
# Backend blocks can't use variables, so the values are literal. If you changed
# the bootstrap defaults, update them here to match `terraform output backend_config`.
terraform {
  backend "s3" {
    bucket         = "capstone-phoenix-tfstate-577817260255"
    key            = "capstone-phoenix/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "capstone-phoenix-tflock"
    encrypt        = true
  }
}
