# # S3 Buckets for dev environment
# resource "aws_s3_bucket" "s3_buckets_dev" {
#   for_each = { for pair in local.bucket_environment_pairs : "${pair.bucket_name}-${pair.environment}" => pair if pair.environment == "dev" }

#   provider = aws.dev

#   bucket = "byt-${each.value.bucket_name}-${each.value.environment}"
#   acl    = "private"

#   tags = {
#     Name        = "byt-${each.value.bucket_name}-${each.value.environment}"
#     Environment = each.value.environment
#     Team        = join(", ", each.value.team_names)
#   }
# }

# # S3 Buckets for prod environment
# resource "aws_s3_bucket" "s3_buckets_prod" {
#   for_each = { for pair in local.bucket_environment_pairs : "${pair.bucket_name}-${pair.environment}" => pair if pair.environment == "prod" }

#   provider = aws.prod

#   bucket = "byt-${each.value.bucket_name}-${each.value.environment}"
#   acl    = "private"

#   tags = {
#     Name        = "byt-${each.value.bucket_name}-${each.value.environment}"
#     Environment = each.value.environment
#     Team        = join(", ", each.value.team_names)
#   }
# }
