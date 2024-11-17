data "aws_iam_role" "existing_api_gateway_s3_role" {
  name = "spain_sub_api_gateway_s3_api_role" # Existing role name
}


# API Gateway REST API
resource "aws_api_gateway_rest_api" "spain_v2_shopify_flow_rest_api" {
  name        = "spain_v2_shopify_flow_rest_api"
  description = "REST API for Shopify Flow integration"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Gateway Resource Path for '/contract'
resource "aws_api_gateway_resource" "spain_v2_resource" {
  rest_api_id = aws_api_gateway_rest_api.spain_v2_shopify_flow_rest_api.id
  parent_id   = aws_api_gateway_rest_api.spain_v2_shopify_flow_rest_api.root_resource_id
  path_part   = var.bucket_name
  depends_on  = [aws_api_gateway_rest_api.spain_v2_shopify_flow_rest_api]
}

# Define POST Method on '/contract'
resource "aws_api_gateway_method" "spain_v2_put_method" {
  rest_api_id   = aws_api_gateway_rest_api.spain_v2_shopify_flow_rest_api.id
  resource_id   = aws_api_gateway_resource.spain_v2_resource.id
  http_method   = "POST"
  authorization = "NONE"
  
  request_parameters = {
    "method.request.querystring.event_type" = true,
    # "method.request.path.bucket" = true
  }
}

resource "aws_api_gateway_integration" "spain_v2_put_integration" {
  rest_api_id             = aws_api_gateway_rest_api.spain_v2_shopify_flow_rest_api.id
  resource_id             = aws_api_gateway_resource.spain_v2_resource.id
  http_method             = aws_api_gateway_method.spain_v2_put_method.http_method
  integration_http_method = "PUT"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${var.region}:s3:path/{bucket}/{key}"
  credentials             = data.aws_iam_role.existing_api_gateway_s3_role.arn # Use existing role
  passthrough_behavior    = "WHEN_NO_MATCH"

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

data "aws_iam_policy" "existing_api_gateway_s3_policy" {
  name = "spain_sub_api_gateway_s3_iam_policy" # Existing policy name
}

data "aws_iam_role" "existing_cloudwatch_role" {
  name = "spain_sub_api_gateway_cloudwatch_global" # Existing CloudWatch role name
}

resource "aws_api_gateway_account" "spain_v2_api_gateway_account_settings" {
  cloudwatch_role_arn = data.aws_iam_role.existing_cloudwatch_role.arn # Use existing role
}

data "aws_cloudwatch_log_group" "existing_log_group" {
  name = "/aws/apigateway/spain_sub_shopify_flow_s3_log" # Existing log group name
}

resource "aws_api_gateway_stage" "spain_v2_api_gateway_stage_log" {
  stage_name    = "subscriptions"
  rest_api_id   = aws_api_gateway_rest_api.spain_v2_shopify_flow_rest_api.id
  deployment_id = aws_api_gateway_deployment.spain_v2_api_gateway_deployment.id

  access_log_settings {
    destination_arn = data.aws_cloudwatch_log_group.existing_log_group.arn # Use existing log group
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
}


resource "aws_sns_topic" "spain_v2_failure_alert_topic" {
  name = "spain_v2_api_gateway_failure_alerts"
}

resource "aws_sns_topic_subscription" "spain_v2_email_subscriptions" {
  for_each  = toset(var.notification_emails)
  topic_arn = aws_sns_topic.spain_v2_failure_alert_topic.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_cloudwatch_metric_alarm" "spain_v2_apigateway_4xx_alarm" {
  alarm_name          = "spain_v2_api_gateway_4XX_Error"
  alarm_description   = "Triggered when API Gateway returns 4XX errors."
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  statistic           = "Sum"
  period              = 300                          # 5-minute evaluation period
  evaluation_periods  = 1                            # Trigger after 1 evaluation period
  threshold           = 1                            # Trigger if 4XXError count >= 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.spain_v2_shopify_flow_rest_api.name
  }

  alarm_actions = [aws_sns_topic.spain_v2_failure_alert_topic.arn]
}


resource "aws_cloudwatch_metric_alarm" "spain_v2_apigateway_5xx_alarm" {
  alarm_name          = "spain_v2_api_gateway_5XX_Error"
  alarm_description   = "Triggered when API Gateway returns 5XX errors."
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  statistic           = "Sum"
  period              = 300                          # 5-minute evaluation period
  evaluation_periods  = 1                            # Trigger after 1 evaluation period
  threshold           = 1                            # Trigger if 5XXError count >= 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.spain_v2_shopify_flow_rest_api.name
  }

  alarm_actions = [aws_sns_topic.spain_v2_failure_alert_topic.arn]
}