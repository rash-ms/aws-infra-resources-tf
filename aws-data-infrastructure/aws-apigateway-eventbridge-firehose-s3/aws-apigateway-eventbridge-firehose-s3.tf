# ==============================
# API Gateway Configuration
# ==============================

resource "aws_apigatewayv2_api" "chargebee_retention_http_api_poc" {
  name          = "chargebee_retention-http-api_poc"
  protocol_type = "HTTP"
}

# Log group for API Gateway
resource "aws_cloudwatch_log_group" "chargebee_retention_api_gateway_logs_poc" {
  name              = "/aws/apigateway/chargebee_retention_http_api_poc"
  retention_in_days = 7
}

# IAM role for API Gateway to log to CloudWatch
resource "aws_iam_role" "chargebee_retention_api_gateway_logs_role_poc" {
  name = "chargebee_retention_api_gateway_logs_role_poc"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "apigateway_cloudwatch_logs_policy" {
  name = "chargebee_retention_apigateway_logs_policy"
  role = aws_iam_role.chargebee_retention_api_gateway_logs_role_poc.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      Effect   = "Allow",
      Resource = "arn:aws:logs:*:*:log-group:/aws/apigateway/*"
    }]
  })
}

# API Gateway stage configuration with logging
resource "aws_apigatewayv2_stage" "chargebee_retention_stage_poc" {
  api_id      = aws_apigatewayv2_api.chargebee_retention_http_api_poc.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.chargebee_retention_api_gateway_logs_poc.arn
    format = jsonencode({
      "requestId"      = "$context.requestId",
      "ip"             = "$context.identity.sourceIp",
      "requestTime"    = "$context.requestTime",
      "domainName"     = "$context.domainName",
      "httpMethod"     = "$context.httpMethod",
      "routeKey"       = "$context.routeKey",
      "status"         = "$context.status",
      "protocol"       = "$context.protocol",
      "responseLength" = "$context.responseLength"
    })
  }
}

# ==============================
# EventBridge Configuration
# ==============================

resource "aws_cloudwatch_event_bus" "chargebee_retention_event_bus_poc" {
  name = "chargebee_retention_event_bus_poc"
}

# Log group for EventBridge
resource "aws_cloudwatch_log_group" "chargebee_retention_event_bus_logs_poc" {
  name              = "/aws/events/chargebee_retention_event_bus_poc"
  retention_in_days = 30
}

# IAM Role for EventBridge logging to CloudWatch
resource "aws_iam_role" "chargebee_retention_eventbridge_logs_role_poc" {
  name = "chargebee_retention_eventbridge_logs_role_poc"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "events.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge_cloudwatch_logs_policy" {
  name = "chargebee_retention_eventbridge_logs_policy"
  role = aws_iam_role.chargebee_retention_eventbridge_logs_role_poc.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      Effect   = "Allow",
      Resource = [
        aws_cloudwatch_log_group.chargebee_retention_event_bus_logs_poc.arn,
        "${aws_cloudwatch_log_group.chargebee_retention_event_bus_logs_poc.arn}:*"
      ]
    }]
  })
}

# EventBridge rule to forward events
resource "aws_cloudwatch_event_rule" "chargebee_retention_eventbridge_rule_poc" {
  name           = "chargebee_retention_eventbridge_rule_poc"
  event_bus_name = aws_cloudwatch_event_bus.chargebee_retention_event_bus_poc.name
  event_pattern = jsonencode({
    "source": ["Chargebee Retention"]
  })
}

# EventBridge target for logging
resource "aws_cloudwatch_event_target" "chargebee_retention_eventbridge_to_log_target_poc" {
  rule           = aws_cloudwatch_event_rule.chargebee_retention_eventbridge_rule_poc.name
  arn            = aws_cloudwatch_log_group.chargebee_retention_event_bus_logs_poc.arn
  # role_arn       = aws_iam_role.chargebee_retention_eventbridge_logs_role_poc.arn
  event_bus_name = aws_cloudwatch_event_bus.chargebee_retention_event_bus_poc.name
}

# ==============================
# Firehose Configuration
# ==============================

# Log group for Firehose
resource "aws_cloudwatch_log_group" "chargebee_retention_firehose_logs_poc" {
  name              = "/aws/kinesisfirehose/chargebee_retention_firehose_to_s3_poc"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_stream" "chargebee_retention_firehose_log_stream_poc" {
  name           = "chargebee_retention_firehose_log_stream_poc"
  log_group_name = aws_cloudwatch_log_group.chargebee_retention_firehose_logs_poc.name
}

# IAM Role for Firehose
resource "aws_iam_role" "chargebee_retention_firehose_role_poc" {
  name = "chargebee_retention_firehose_role_poc"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "firehose.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "firehose_cloudwatch_policy" {
  name = "chargebee_retention_firehose_policy"
  role = aws_iam_role.chargebee_retention_firehose_role_poc.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "logs:PutLogEvents",
        "logs:CreateLogStream",
        "logs:DescribeLogStreams"
      ],
      Effect   = "Allow",
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}

# Firehose delivery stream to S3 with logging
resource "aws_kinesis_firehose_delivery_stream" "chargebee_retention_firehose_to_s3_poc" {
  name        = "chargebee_retention-firehose-to-s3_poc"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn            = aws_iam_role.chargebee_retention_firehose_role_poc.arn
    bucket_arn          = "arn:aws:s3:::${var.martech_s3_bucket}"
    prefix              = "outbounds/chargebee_retention/"
    error_output_prefix = "errors/chargebee_retention/"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.chargebee_retention_firehose_logs_poc.name
      log_stream_name = aws_cloudwatch_log_stream.chargebee_retention_firehose_log_stream_poc.name
    }
  }
}
