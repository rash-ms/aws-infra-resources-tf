# # API Gateway Deployment updated to depend on the stage
# resource "aws_api_gateway_deployment" "spain_sub_apigateway_s3_deployment" {

#   # Use triggers to force deployment
#   triggers = {
#     stage_description = md5(file("${path.module}/api-resources-setup.tf"))
#       # stage_description = local.stage_name
#       }
#   rest_api_id = aws_api_gateway_rest_api.spain_sub_apigateway_shopify_flow_rest_api.id
  
#   depends_on = [
#     aws_api_gateway_method.spain_sub_apigateway_create_method,
#     aws_api_gateway_integration.spain_sub_apigateway_s3_integration_request,
#     aws_api_gateway_integration_response.spain_sub_apigateway_s3_integration_response,
#     aws_api_gateway_method_response.spain_sub_apigateway_s3_method_response
#   ]
# }


locals {
  stage_name     = "subscriptionsv001"
  log_group_name = "/aws/apigateway/spain_sub_apigateway_s3_shopify_flow_${local.stage_name}"

  # Generate a hash of the stage_name to detect changes
  stage_name_hash = md5(local.stage_name)

  # Use stage_name_hash to determine if the deployment timestamp should change
  deploy_at = "${local.stage_name_hash}-${timestamp()}"
}

# locals {
#   stage_name     = "subscriptionsv02"
#   # deployed_at    = timestamp()
#   log_group_name = "/aws/apigateway/spain_sub_apigateway_s3_shopify_flow_${local.stage_name}"
# }

# IAM Role for API Gateway to access S3
resource "aws_iam_role" "spain_sub_apigateway_s3_api_role" {
  name                 = "spain_sub_apigateway_s3_api_role"

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
resource "aws_iam_policy" "spain_sub_apigateway_s3_iam_policy" {
  name = "spain_sub_apigateway_s3_iam_policy"
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
          "arn:aws:s3:::${var.fivetran_s3_bucket}",
          "arn:aws:s3:::${var.fivetran_s3_bucket}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DeleteLogGroup"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "apigateway:POST",
          "apigateway:PUT",
          "apigateway:DELETE",               
          "apigateway:PATCH",               
          "apigateway:GET",                
          "apigateway:FlushStageCache"
          
        ],
        "Resource": "arn:aws:apigateway:*::/restapis/*" // All APIs in all regions
      }
    ]
  })
}

# Attach the IAM Policy to the Role
resource "aws_iam_role_policy_attachment" "spain_sub_apigateway_role_policy_attachment" {
  role       = aws_iam_role.spain_sub_apigateway_s3_api_role.name
  policy_arn = aws_iam_policy.spain_sub_apigateway_s3_iam_policy.arn
}

data "aws_iam_policy_document" "spain_sub_apigateway_s3_cloudwatch_assume_role" {
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

resource "aws_iam_role" "spain_sub_cloudwatch_role" {
  name               = "spain_sub_cloudwatch_role"
  assume_role_policy = data.aws_iam_policy_document.spain_sub_apigateway_s3_cloudwatch_assume_role.json
}

resource "aws_api_gateway_account" "spain_sub_apigateway_account_settings" {
  cloudwatch_role_arn = aws_iam_role.spain_sub_cloudwatch_role.arn
}

resource "aws_iam_role_policy" "spain_sub_cloudwatch_policy" {
  name   = "spain_sub_cloudwatch_policy"
  role   = aws_iam_role.spain_sub_cloudwatch_role.id
  policy = data.aws_iam_policy_document.spain_sub_get_cloudwatch_policy.json
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "spain_sub_apigateway_shopify_flow_rest_api" {
  name        = "spain_sub_apigateway_shopify_flow_rest_api"
  description = "REST API for Shopify Flow integration"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Gateway Resource Path for '/bucket_name'
resource "aws_api_gateway_resource" "spain_sub_apigateway_create_resource" {
  rest_api_id = aws_api_gateway_rest_api.spain_sub_apigateway_shopify_flow_rest_api.id
  parent_id   = aws_api_gateway_rest_api.spain_sub_apigateway_shopify_flow_rest_api.root_resource_id
  # path_part   = var.fivetran_s3_bucket
  path_part   = "{bucket_name}" 
  depends_on  = [aws_api_gateway_rest_api.spain_sub_apigateway_shopify_flow_rest_api]
}

# Define POST Method on '/bucket_name'
resource "aws_api_gateway_method" "spain_sub_apigateway_create_method" {
  rest_api_id   = aws_api_gateway_rest_api.spain_sub_apigateway_shopify_flow_rest_api.id
  resource_id   = aws_api_gateway_resource.spain_sub_apigateway_create_resource.id
  http_method   = "POST"
  authorization = "NONE"

  request_parameters = {
    "method.request.querystring.event_type" = true,
    "method.request.path.bucket_name" = true
  }
}

# # API Gateway Integration with S3 for the PUT request
resource "aws_api_gateway_integration" "spain_sub_apigateway_s3_integration_request" {
  rest_api_id             = aws_api_gateway_rest_api.spain_sub_apigateway_shopify_flow_rest_api.id
  resource_id             = aws_api_gateway_resource.spain_sub_apigateway_create_resource.id
  http_method             = aws_api_gateway_method.spain_sub_apigateway_create_method.http_method
  integration_http_method = "PUT"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${var.region}:s3:path/{bucket_name}/{key}"
  credentials             = aws_iam_role.spain_sub_apigateway_s3_api_role.arn
  # passthrough_behavior    = "WHEN_NO_MATCH"
  passthrough_behavior    = "WHEN_NO_TEMPLATES"  # Dynamically propagate errors from S3

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/json'",
    "integration.request.path.bucket_name" = "method.request.path.bucket_name"
  }
  
#set($context.requestOverride.path.bucket_name = "${var.fivetran_s3_bucket}")
#set($context.requestOverride.path.bucket_name = "$input.params('bucket_name')")

  request_templates = {
    "application/json" = <<EOT
#set($eventType = $input.json('event_type').replaceAll('"', ''))
#set($epochString = $context.requestTimeEpoch.toString())
#set($pathName =  $eventType + "/" + $eventType + "_" + $epochString + ".json") 
#set($key = "raw/" + $pathName)
#set($context.requestOverride.path.bucket_name = "$input.params('bucket_name')")
#set($context.requestOverride.path.key = $key)
{
    "body": $input.body
}
EOT
  }
}

resource "aws_api_gateway_integration_response" "spain_sub_apigateway_s3_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.spain_sub_apigateway_shopify_flow_rest_api.id
  resource_id = aws_api_gateway_resource.spain_sub_apigateway_create_resource.id
  http_method = aws_api_gateway_method.spain_sub_apigateway_create_method.http_method
  status_code = "200"
  depends_on = [
    aws_api_gateway_integration.spain_sub_apigateway_s3_integration_request
  ]

  # response_templates = {
  #   "application/json" = <<EOT
  #   {
  #       "message": "File uploaded successfully",
  #       "bucket": "$context.requestOverride.path.bucket",
  #       "key": "$context.requestOverride.path.key"
  #   }
  #   EOT
  # }

  response_parameters = {
    "method.response.header.x-amz-request-id" = "integration.response.header.x-amz-request-id",
    "method.response.header.etag"             = "integration.response.header.ETag"
  }
}

resource "aws_api_gateway_method_response" "spain_sub_apigateway_s3_method_response" {
  rest_api_id = aws_api_gateway_rest_api.spain_sub_apigateway_shopify_flow_rest_api.id
  resource_id = aws_api_gateway_resource.spain_sub_apigateway_create_resource.id
  http_method = aws_api_gateway_method.spain_sub_apigateway_create_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.x-amz-request-id" = true,
    "method.response.header.etag"             = true
  }
  response_models = {
    "application/json" = "Empty"
  }
}



# API Gateway Deployment updated to depend on the stage
resource "aws_api_gateway_deployment" "spain_sub_apigateway_s3_deployment" {

  # Use triggers to force deployment
  # triggers = {
  #   stage_description = md5(file("${path.module}/api-resources-resources.tf"))
  #     # stage_description = local.stage_name
  #     }
  # Triggers for forced deployment/redeployment
  triggers = {
    stage_name_hash = local.stage_name_hash
    deploy_at       = local.deploy_at
  }

  rest_api_id = aws_api_gateway_rest_api.spain_sub_apigateway_shopify_flow_rest_api.id
  
  depends_on = [
    aws_api_gateway_method.spain_sub_apigateway_create_method,
    aws_api_gateway_integration.spain_sub_apigateway_s3_integration_request,
    aws_api_gateway_integration_response.spain_sub_apigateway_s3_integration_response,
    aws_api_gateway_method_response.spain_sub_apigateway_s3_method_response
  ]
}


# CloudWatch Log Group for API Gateway Logs
resource "aws_cloudwatch_log_group" "spain_sub_apigateway_log_group" {
  name              = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.spain_sub_apigateway_shopify_flow_rest_api.id}/${local.stage_name}"
  retention_in_days = 7
}

# API Gateway Stage with CloudWatch Logging Enabled
resource "aws_api_gateway_stage" "spain_sub_apigateway_stage" {
  stage_name    = local.stage_name
  rest_api_id   = aws_api_gateway_rest_api.spain_sub_apigateway_shopify_flow_rest_api.id
  deployment_id = aws_api_gateway_deployment.spain_sub_apigateway_s3_deployment.id
  # deployment_id = "${aws_api_gateway_deployment.spain_sub_apigateway_s3_deployment.id}"

  cache_cluster_enabled = true
  cache_cluster_size    = "0.5"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.spain_sub_apigateway_log_group.arn
    format = jsonencode({
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
  depends_on = [aws_api_gateway_account.spain_sub_apigateway_account_settings]

#   lifecycle {
#     create_before_destroy = true
#   }
}

# Configure Method Settings for Detailed Logging and Caching
resource "aws_api_gateway_method_settings" "spain_sub_apigateway_method_settings" {
  rest_api_id = aws_api_gateway_rest_api.spain_sub_apigateway_shopify_flow_rest_api.id
  stage_name  = aws_api_gateway_stage.spain_sub_apigateway_stage.stage_name
  method_path = "*/*" # Apply to all methods and resources

  settings {
    metrics_enabled      = true   # Enable CloudWatch metrics
    logging_level        = "INFO" # Set logging level to INFO
    data_trace_enabled   = true   # Enable data trace logging
    caching_enabled      = true   # Enable caching
    cache_ttl_in_seconds = 300    # Set TTL for cache (5 minutes)
  }
}

resource "aws_sns_topic" "spain_sub_apigateway_failure_alert_topic" {
  name = "spain_sub_apigateway_failure_alerts"
}

resource "aws_sns_topic_subscription" "spain_sub_apigateway_email_alert_notification" {
  for_each  = toset(var.notification_emails)
  topic_arn = aws_sns_topic.spain_sub_apigateway_failure_alert_topic.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_cloudwatch_metric_alarm" "spain_sub_apigateway_4xx_alarm" {
  alarm_name          = "spain_sub_apigateway_4XX_Error"
  alarm_description   = "Triggered when API Gateway returns 4XX errors."
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  statistic           = "Sum"
  period              = 300 # 5-minute evaluation period
  evaluation_periods  = 1   # Trigger after 1 evaluation period
  threshold           = 1   # Trigger if 4XXError count >= 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.spain_sub_apigateway_shopify_flow_rest_api.name
  }

  alarm_actions = [aws_sns_topic.spain_sub_apigateway_failure_alert_topic.arn]
}

resource "aws_cloudwatch_metric_alarm" "spain_sub_apigateway_5xx_alarm" {
  alarm_name          = "spain_sub_apigateway_5XX_Error"
  alarm_description   = "Triggered when API Gateway returns 5XX errors."
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  statistic           = "Sum"
  period              = 300 # 5-minute evaluation period
  evaluation_periods  = 1   # Trigger after 1 evaluation period
  threshold           = 1   # Trigger if 5XXError count >= 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.spain_sub_apigateway_shopify_flow_rest_api.name
  }

  alarm_actions = [aws_sns_topic.spain_sub_apigateway_failure_alert_topic.arn]
}
