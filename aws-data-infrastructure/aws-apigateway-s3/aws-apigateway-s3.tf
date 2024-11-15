# Reference an existing S3 bucket
data "aws_s3_bucket" "spain_sub_event_bucket" {
  bucket = var.bucket_name
}

# IAM Role for API Gateway to access S3
resource "aws_iam_role" "spain_sub_api_gateway_s3_api_role" {
  name = "spain_sub_api_gateway_s3_api_role"

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
resource "aws_iam_policy" "spain_sub_api_gateway_s3_iam_policy" {
  name = "spain_sub_api_gateway_s3_iam_policy"
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
          "arn:aws:s3:::byt-test-prod/*",
          "arn:aws:s3:::byt-test-prod/bronze/*",
          "arn:aws:s3:::${data.aws_s3_bucket.spain_sub_event_bucket.bucket}/*"
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
  role       = aws_iam_role.spain_sub_api_gateway_s3_api_role.name
  policy_arn = aws_iam_policy.spain_sub_api_gateway_s3_iam_policy.arn
}


# CloudWatch Log Group for API Gateway Logs
resource "aws_cloudwatch_log_group" "spain_sub_api_gateway_log_group" {
  name              = "/aws/apigateway/spain_sub_shopify_flow_s3_log"
  retention_in_days = 7
}


data "aws_iam_policy_document" "cloudwatch_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


data "aws_iam_policy_document" "spain_sub_get_cloudwatch_policy" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role" "api_gateway_cloudwatch_global" {
  name               = "api_gateway_cloudwatch_global"
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_assume_role.json
}


resource "aws_api_gateway_account" "api_gateway_account_settings" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_global.arn
}


resource "aws_iam_role_policy" "spain_sub_cloudwatch_policy" {
  name   = "spain_sub_cloudwatch_policy"
  role   = aws_iam_role.api_gateway_cloudwatch_global.id
  policy = data.aws_iam_policy_document.spain_sub_get_cloudwatch_policy.json
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

# Define POST Method on '/contract'
resource "aws_api_gateway_method" "spain_sub_put_method" {
  rest_api_id   = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
  resource_id   = aws_api_gateway_resource.spain_sub_resource.id
  http_method   = "PUT"
  authorization = "NONE"
  
  request_parameters = {
    "method.request.querystring.event_type" = true, 
    "method.request.path.object_key" = true
    # "method.request.path.foldername" = true,
    # "method.request.path.filename"   = true
  }
}


# # API Gateway Integration with S3 for the PUT request
resource "aws_api_gateway_integration" "spain_sub_put_integration" {
  rest_api_id             = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
  resource_id             = aws_api_gateway_resource.spain_sub_resource.id
  http_method             = aws_api_gateway_method.spain_sub_put_method.http_method
  integration_http_method = "PUT"  # S3 requires PUT for object creation
  type                    = "AWS"
  # uri                     = "arn:aws:apigateway:${var.region}:s3:path/${data.aws_s3_bucket.spain_sub_event_bucket.bucket}"
  # uri                     = "arn:aws:apigateway:${var.region}:s3:path/${data.aws_s3_bucket.spain_sub_event_bucket.bucket}/{object}"
  # uri                     = "arn:aws:apigateway:${var.region}:s3:path/${data.aws_s3_bucket.spain_sub_event_bucket.bucket}/{foldername}/{filename}"
  uri                     = "arn:aws:apigateway:${var.region}:s3:path/${data.aws_s3_bucket.spain_sub_event_bucket.bucket}/{object_key}"
  credentials             = aws_iam_role.spain_sub_api_gateway_s3_api_role.arn
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_parameters = {
    # "integration.request.header.Content-Type" = "'application/json'"
    # "integration.request.path.object" = "method.request.path.object"
    # "integration.request.path.foldername" = "method.request.path.foldername",
    # "integration.request.path.filename"   = "method.request.path.filename",
    "integration.request.path.object_key" = "method.request.path.object_key",
    "integration.request.header.Content-Type" = "'application/json'"
  }

  request_templates = {
    "application/json" = <<EOF
#set($timestamp = $context.requestTimeEpoch)
#set($eventType = $input.path('$.event_type'))
#set($pathName = "bronze")
#set($object_key = $pathName + "/" + $eventType + "/" + $eventType + "_" + $timestamp + ".json")
#set($context.requestOverride.path.object_key = $object_key)
{
  "object_key": "$object_key",
  "body": $input.json('$')
}
EOF
  }
}

#   request_templates = {
#     "application/json" = <<EOF
# #set($timestamp = $context.requestTimeEpoch)
# #set($eventType = $input.path('$.event_type'))
# #set($pathName = "bronze")
# #set($foldername = $pathName + "/" + $eventType)
# #set($filename = $eventType + "_" + $timestamp + ".json")
# #set($context.requestOverride.path.foldername = $foldername)
# #set($context.requestOverride.path.filename = $filename)
# {
#   "foldername": "$foldername",
#   "filename": "$filename",
#   "body": $input.json('$')
# }
# EOF
#   }
# }


#   request_templates = {
#     "application/json" = <<EOF
# #set($timestamp = $context.requestTimeEpoch)
# #set($eventType = $input.path('$.event_type'))
# #set($pathName = "bronze")
# #set($object = $pathName + "/" + $eventType + "/" + $eventType + "_" + $timestamp + ".json")
# {
#   "bucket": "${var.bucket_name}",
#   "key": "$object",
#   "body": $input.json('$')
# }
# EOF
#   }
# }


# API Gateway Deployment updated to depend on the stage
resource "aws_api_gateway_deployment" "spain_sub_api_gateway_deployment" {
  rest_api_id = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
  depends_on  = [
    aws_api_gateway_method.spain_sub_put_method,
    aws_api_gateway_integration.spain_sub_put_integration
  ]
}



# API Gateway Stage with CloudWatch Logging Enabled
resource "aws_api_gateway_stage" "spain_sub_api_gateway_stage_log" {
  stage_name    = "subscriptions"
  rest_api_id   = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
  deployment_id = aws_api_gateway_deployment.spain_sub_api_gateway_deployment.id

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.spain_sub_api_gateway_log_group.arn
    format          = jsonencode({
      "requestId"      = "$context.requestId",
      "ip"             = "$context.identity.sourceIp",
      "requestTime"    = "$context.requestTime",
      "httpMethod"     = "$context.httpMethod",
      "resourcePath"   = "$context.resourcePath",
      "status"         = "$context.status",
      "responseLength" = "$context.responseLength",
      "userAgent"      = "$context.identity.userAgent",
      "error"          = "$context.error.message"
    })
  }

  xray_tracing_enabled = true
  tags = {
    "Name" = "spain_sub_shopify_flow_log"
  }

  depends_on = [aws_api_gateway_account.api_gateway_account_settings]
}

# Configure Method Settings for Detailed Logging
resource "aws_api_gateway_method_settings" "spain_sub_api_gateway_method_settings" {
  rest_api_id = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
  stage_name  = aws_api_gateway_stage.spain_sub_api_gateway_stage_log.stage_name
  method_path = "*/*"  # Apply to all methods

  settings {
    metrics_enabled       = true               # Enables CloudWatch metrics for this method
    logging_level         = "INFO"             # Set to "ERROR" for error-only logs, "INFO" for detailed logs
    data_trace_enabled    = true               # Enables detailed request/response logging
    caching_enabled       = false
  }
}
