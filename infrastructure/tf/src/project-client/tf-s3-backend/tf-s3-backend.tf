terraform {
  required_version = ">= 0.14.7"
  
  backend "s3" {
    bucket         = "ms-data-infra-backend"   
    key            = "terraform.tfstate"       
    region         = "us-east-1"               
    encrypt        = true                      
    dynamodb_table = "terraform_locks"         
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "backend" {
  bucket = "ms-data-infra-backend"
  acl    = "private"

  tags = {
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "backend_versioning" {
  bucket = aws_s3_bucket.backend.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backend_encryption" {
  bucket = aws_s3_bucket.backend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
