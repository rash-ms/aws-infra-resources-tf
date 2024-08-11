locals {
  bucket_config = yamldecode(file("${path.module}/aws-s3-bucket-yaml/us/us-workspace-s3-buckets.yaml"))
}

locals {
  bucket_environment_pairs = flatten([
    for bucket_name, bucket_data in local.bucket_config : [
      for env in bucket_data.project-environment : {
        bucket_name    = bucket_name
        environment    = env
        region         = bucket_data.region
        team_names     = bucket_data["project-team-names"]
      }
    ]
  ])
}