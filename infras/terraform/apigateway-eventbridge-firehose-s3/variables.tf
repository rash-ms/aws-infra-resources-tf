variable "region" {
  default = "us-east-1"  # Set your AWS region
}

variable "martech_s3_bucket" {
  # default = "byt-test-flow-api"
  default = "byt-test-flow-app" 
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

