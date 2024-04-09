terraform {
  required_version = ">=v0.14.7"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "backend" {
  bucket = "ms-data-infra-backend"
  tags = {
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket_acl" "backend_acl" {
  bucket = aws_s3_bucket.backend.id
  acl    = "private"
}


# terraform {
#   required_version = ">= 0.14.7"
# }

# provider "aws" {
#   region = "us-east-1"
# }

# resource "aws_s3_bucket" "backend" {
#   bucket = "ms-data-infra-backend"
#   tags = {
#     ManagedBy = "Terraform"
#   }
# }

# resource "aws_s3_bucket_versioning" "backend_versioning" {
#   bucket = aws_s3_bucket.backend.id

#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "backend_encryption" {
#   bucket = aws_s3_bucket.backend.id

#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }
