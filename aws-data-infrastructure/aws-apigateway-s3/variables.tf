variable "region" {
  default = "us-east-1"  # Set your AWS region
}

variable "bucket_name" {
  default = "byt-test-prod"  # Name of the existing S3 bucket
}

variable "integration_version" {
  description = "A version number to force update on API Gateway integration."
  default     = "2"  # Increment this whenever you modify request_templates or request_parameters
}

# variable "region" {
#   type = string
# }

# variable "account_id" {
#   type = string
# }

# variable "environment" {
#   type    = string
#   default = "stg"
# }

# variable "test_s3_bucket" {
#   type    = string
#   default = "stg"
# }


# variable "tenant_name" {
#   type    = string
#   default = "data-platform"
# }

# # tags to be applied to resource
# variable "tags" {
#   type = map(any)

#   default = {
#     "created_by"  = "terraform"
#     "application" = "data-platform-infra"
#     "owner"       = "data-platform"
#   }
# }