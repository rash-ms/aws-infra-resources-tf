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

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Gateway Resource Path for '/contract'
resource "aws_api_gateway_resource" "spain_sub_resource" {
  rest_api_id = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
  parent_id   = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.root_resource_id
  path_part   = var.bucket_name
  depends_on  = [aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api]
}

# Define POST Method on '/contract'
resource "aws_api_gateway_method" "spain_sub_put_method" {
  rest_api_id   = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
  resource_id   = aws_api_gateway_resource.spain_sub_resource.id
  http_method   = "POST"
  authorization = "NONE"
  
  request_parameters = {
    "method.request.querystring.event_type" = true,
    # "method.request.path.bucket" = true
  }
}


# # API Gateway Integration with S3 for the PUT request
resource "aws_api_gateway_integration" "spain_sub_put_integration" {
  rest_api_id             = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
  resource_id             = aws_api_gateway_resource.spain_sub_resource.id
  http_method             = aws_api_gateway_method.spain_sub_put_method.http_method
  integration_http_method = "PUT"  
  type                    = "AWS"
#   uri                     = "arn:aws:apigateway:${var.region}:s3:path/{bucket}/{key}"
  uri                     = "arn:aws:apigateway:${var.region}:s3:path/{bucket}"
  credentials             = aws_iam_role.spain_sub_api_gateway_s3_api_role.arn
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/json'",
    # "integration.request.path.bucket" = "method.request.path.bucket"
    # "integration.request.path.bucket" = "method.request.path.bucket"
  }

# #set($context.requestOverride.path.bucket = "$input.params('bucket')")
# #set($context.requestOverride.path.bucket = "${var.bucket_name}")

  request_templates = {
    "application/json" = <<EOT

#set($eventType = $input.json('event_type').replaceAll('"', ''))
#set($epochString = $context.requestTimeEpoch.toString())
#set($pathName =  $eventType + "/" + $eventType + "_" + $epochString + ".json") 
#set($key = "bronze/" + $pathName)
#set($context.requestOverride.path.bucket = "${var.bucket_name}")
#set($context.requestOverride.path.key = $key)
{
    "body": $input.body
}
EOT
  }
}


resource "aws_api_gateway_integration_response" "spain_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
  resource_id = aws_api_gateway_resource.spain_sub_resource.id
  http_method = aws_api_gateway_method.spain_sub_put_method.http_method
  status_code = "200"

  depends_on = [
    aws_api_gateway_integration.spain_sub_put_integration
  ]

  response_templates = {
    "application/json" = <<EOT
    {
        "message": "File uploaded successfully",
        "bucket": "$context.requestOverride.path.bucket",
        "key": "$context.requestOverride.path.key"
    }
    EOT
  }

  response_parameters = {
    "method.response.header.x-amz-request-id" = "integration.response.header.x-amz-request-id",
    "method.response.header.etag"            = "integration.response.header.ETag"
  }
}


resource "aws_api_gateway_method_response" "spain_method_response" {
  rest_api_id = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
  resource_id = aws_api_gateway_resource.spain_sub_resource.id
  http_method = aws_api_gateway_method.spain_sub_put_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.x-amz-request-id" = true,
    "method.response.header.etag"            = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}


# API Gateway Deployment updated to depend on the stage
resource "aws_api_gateway_deployment" "spain_sub_api_gateway_deployment" {
  rest_api_id = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
  depends_on  = [
    aws_api_gateway_method.spain_sub_put_method,
    aws_api_gateway_integration.spain_sub_put_integration,
    aws_api_gateway_integration_response.spain_integration_response,
    aws_api_gateway_method_response.spain_method_response
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
  method_path = "*/*"  

  settings {
    metrics_enabled       = true               
    logging_level         = "INFO"            
    data_trace_enabled    = true              
    caching_enabled       = false
  }
}


resource "aws_sns_topic" "spain_sub_failure_alert_topic" {
  name = "spain_sub_api_gateway_failure_alerts"
}

resource "aws_sns_topic_subscription" "spain_sub_email_subscriptions" {
  for_each  = toset(var.notification_emails)
  topic_arn = aws_sns_topic.spain_sub_failure_alert_topic.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_cloudwatch_metric_alarm" "spain_sub_apigateway_4xx_alarm" {
  alarm_name          = "spain_sub_api_gateway_4XX_Error"
  alarm_description   = "Triggered when API Gateway returns 4XX errors."
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  statistic           = "Sum"
  period              = 300                          # 5-minute evaluation period
  evaluation_periods  = 1                            # Trigger after 1 evaluation period
  threshold           = 1                            # Trigger if 4XXError count >= 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.name
  }

  alarm_actions = [aws_sns_topic.spain_sub_failure_alert_topic.arn]
}


resource "aws_cloudwatch_metric_alarm" "spain_sub_apigateway_5xx_alarm" {
  alarm_name          = "spain_sub_api_gateway_5XX_Error"
  alarm_description   = "Triggered when API Gateway returns 5XX errors."
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  statistic           = "Sum"
  period              = 300                          # 5-minute evaluation period
  evaluation_periods  = 1                            # Trigger after 1 evaluation period
  threshold           = 1                            # Trigger if 5XXError count >= 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.name
  }

  alarm_actions = [aws_sns_topic.spain_sub_failure_alert_topic.arn]
}
