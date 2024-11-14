# Reference an existing S3 bucket
data "aws_s3_bucket" "spain_sub_event_bucket" {
  bucket = var.bucket_name
}

# IAM Role for API Gateway to access S3
resource "aws_iam_role" "spain_sub_shopify_flow_api_role" {
  name = "spain_sub_shopify_flow_api_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "apigateway.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# IAM Policy for S3 access and CloudWatch logging
resource "aws_iam_policy" "spain_sub_shopify_flow_iam_policy" {
  name = "spain_sub_shopify_flow_iam_policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::byt-test-prod",
          "arn:aws:s3:::byt-test-prod/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Attach the IAM Policy to the Role
resource "aws_iam_role_policy_attachment" "spain_sub_api_gateway_role_policy_attachment" {
  role       = aws_iam_role.spain_sub_shopify_flow_api_role.name
  policy_arn = aws_iam_policy.spain_sub_shopify_flow_iam_policy.arn
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "spain_sub_shopify_flow_rest_api" {
  name        = "spain_sub_shopify_flow_rest_api"
  description = "REST API for Shopify Flow integration"
}

# API Gateway Resource Path for '/contract'
resource "aws_api_gateway_resource" "spain_sub_resource" {
  rest_api_id = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
  parent_id   = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.root_resource_id
  path_part   = "contract"
  depends_on  = [aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api]
}

# Define GET Method on '/contract'
resource "aws_api_gateway_method" "spain_sub_get_method" {
  rest_api_id   = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
  resource_id   = aws_api_gateway_resource.spain_sub_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# Define POST Method on '/contract'
resource "aws_api_gateway_method" "spain_sub_post_method" {
  rest_api_id   = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
  resource_id   = aws_api_gateway_resource.spain_sub_resource.id
  http_method   = "POST"
  authorization = "NONE"
  
  request_parameters = {
    "method.request.querystring.event_type" = true  # Require event_type as a query parameter
  }
}


# API Gateway Integration with S3 for the POST request
resource "aws_api_gateway_integration" "spain_sub_post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
  resource_id             = aws_api_gateway_resource.spain_sub_resource.id
  http_method             = aws_api_gateway_method.spain_sub_post_method.http_method
  integration_http_method = "PUT"  # S3 requires PUT for object creation
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${var.region}:s3:path/${data.aws_s3_bucket.spain_sub_event_bucket.bucket}/bronze/events/{event_type}/{event_type}.json"
  credentials             = aws_iam_role.spain_sub_shopify_flow_api_role.arn
  passthrough_behavior    = "WHEN_NO_MATCH"

  # Pass event_type to the S3 path dynamically
  request_parameters = {
    "integration.request.path.event_type" = "method.request.querystring.event_type"
  }

  # Mapping template for the S3 object key and body
  request_templates = {
    "application/json" = <<EOF
#set($datetime = $context.requestTimeEpoch)
{
  "bucket": "${data.aws_s3_bucket.spain_sub_event_bucket.bucket}",
  "key": "bronze/events/$input.params('event_type')/$input.params('event_type')_${datetime}.json",
  "body": "$util.base64Encode($input.body)"
}
EOF
  }
}


# CloudWatch Log Group for API Gateway Logs
resource "aws_cloudwatch_log_group" "spain_sub_api_gateway_log_group" {
  name              = "/aws/apigateway/spain_sub_shopify_flow_rest_api"
  retention_in_days = 7
}

# API Gateway Deployment and Stage with CloudWatch Logging Enabled
resource "aws_api_gateway_deployment" "spain_sub_api_gateway_deployment" {
  rest_api_id = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
  depends_on  = [aws_api_gateway_integration.spain_sub_post_integration]
  stage_name  = "subscriptions"
}
