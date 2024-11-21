variable "region" {
  default = "us-east-1"  # Set your AWS region
}

variable "fivetran_s3_bucket" {
  default = "byt-test-flow-api" #"byt-test-prod"  # Name of the existing S3 bucket
}

variable "notification_emails" {
  description = "List of email addresses to receive alerts"
  type        = list(string)
  default     = ["mujeeb.adeniji@condenast.com", "email2@example.com"]
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