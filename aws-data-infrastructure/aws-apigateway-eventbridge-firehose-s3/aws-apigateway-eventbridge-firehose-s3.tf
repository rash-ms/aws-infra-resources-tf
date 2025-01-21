resource "aws_apigatewayv2_api" "chargebee_retention_http_api_poc" {
  name          = "chargebee_retention-http-api_poc"
  protocol_type = "HTTP"
}

resource "aws_cloudwatch_log_group" "chargebee_retention_api_gateway_logs_poc" {
  name              = "/aws/apigateway/chargebee_retention-http-api_poc"
  retention_in_days = 7
}

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

# Create EventBridge
resource "aws_cloudwatch_event_bus" "chargebee_retention_event_bus_poc" {
  name = "chargebee_retention_event_bus_poc"
}

resource "aws_cloudwatch_log_group" "chargebee_retention_event_bus_logs_poc" {
  name              = "/aws/events/chargebee_retention_event_bus_poc"
  retention_in_days = 30
}

# # EventBridge Permission for API Gateway
# resource "aws_cloudwatch_event_permission" "allow_apigateway_to_eventbridge" {
#   event_bus_name = aws_cloudwatch_event_bus.chargebee_retention_event_bus_poc.name
#   principal      = "apigateway.amazonaws.com"
#   action         = "events:PutEvents"
#   statement_id   = "AllowApiGatewayToPutEvents"
# }

resource "aws_cloudwatch_event_permission" "allow_apigateway_to_eventbridge" {
  event_bus_name = aws_cloudwatch_event_bus.chargebee_retention_event_bus_poc.name
  principal      = "*" # Allow all principals but restrict via conditions
  action         = "events:PutEvents"
  statement_id   = "AllowApiGatewayToPutEvents"
}



# IAM Role for API Gateway to EventBridge
resource "aws_iam_role" "chargebee_retention_api_gateway_eventbridge_role_poc" {
  name                 = "chargebee_retention_api_gateway_eventbridge_role_poc"
  # permissions_boundary = "arn:aws:iam::${var.account_id}:policy/tenant-${var.tenant_name}-boundary"


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

resource "aws_iam_role_policy" "chargebee_retention_api_gateway_eventbridge_policy_poc" {
  name = "chargebee_retention_api_gateway_eventbridge_policy_poc"
  role = aws_iam_role.chargebee_retention_api_gateway_eventbridge_role_poc.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "events:PutEvents"
      ],
      Effect   = "Allow",
      Resource = aws_cloudwatch_event_bus.chargebee_retention_event_bus_poc.arn
    }]
  })
}

# API Gateway to EventBridge Integration
resource "aws_apigatewayv2_integration" "chargebee_retention_integration_poc" {
  api_id              = aws_apigatewayv2_api.chargebee_retention_http_api_poc.id
  integration_type    = "AWS_PROXY"
  integration_subtype = "EventBridge-PutEvents"
  request_parameters = {
    EventBusName = aws_cloudwatch_event_bus.chargebee_retention_event_bus_poc.name
    Detail       = "$request.body"
    DetailType   = "DefaultEventType"
    Source       = "Chargebee Retention"
  }
  credentials_arn = aws_iam_role.chargebee_retention_api_gateway_eventbridge_role_poc.arn
}

resource "aws_apigatewayv2_route" "chargebee_retention_route_poc" {
  api_id    = aws_apigatewayv2_api.chargebee_retention_http_api_poc.id
  route_key = "ANY /"
  target    = "integrations/${aws_apigatewayv2_integration.chargebee_retention_integration_poc.id}"
}

# IAM Role for EventBridge to Firehose
resource "aws_iam_role" "chargebee_retention_eventbridge_firehose_role_poc" {
  name                 = "chargebee_retention_eventbridge_firehose_role_poc"
 # permissions_boundary = "arn:aws:iam::${var.account_id}:policy/tenant-${var.tenant_name}-boundary"


  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "chargebee_retention_eventbridge_firehose_policy_poc" {
  name = "chargebee_retention_eventbridge_firehose_policy_poc"
  role = aws_iam_role.chargebee_retention_eventbridge_firehose_role_poc.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "firehose:PutRecord",
        "firehose:PutRecordBatch"
      ],
      Effect   = "Allow",
      Resource = aws_kinesis_firehose_delivery_stream.chargebee_retention_firehose_to_s3_poc.arn
      },
      {
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ],
        Effect = "Allow",
        Resource = [
          "arn:aws:s3:::${var.martech_s3_bucket}",
          "arn:aws:s3:::${var.martech_s3_bucket}/*"
        ]
      },
      {
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*",

    }]
  })
}

# IAM Role for EventBridge to write to CloudWatch Logs
resource "aws_iam_role" "chargebee_retention_eventbridge_to_cloudwatch_role_poc" {
  name                 = "chargebee_retention_eventbridge_to_cloudwatch_role_poc"
#  permissions_boundary = "arn:aws:iam::${var.account_id}:policy/tenant-${var.tenant_name}-boundary"


  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "chargebee_retention_eventbridge_to_cloudwatch_policy_poc" {
  name = "chargebee_retention_eventbridge_to_cloudwatch_policy_poc"
  role = aws_iam_role.chargebee_retention_eventbridge_to_cloudwatch_role_poc.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams"

        ],
        Effect = "Allow",
        Resource = [
          aws_cloudwatch_log_group.chargebee_retention_event_bus_logs_poc.arn,
          "${aws_cloudwatch_log_group.chargebee_retention_event_bus_logs_poc.arn}:*"
        ]
      }
    ]
  })
}

# EventBridge Rule
resource "aws_cloudwatch_event_rule" "chargebee_retention_eventbridge_to_firehose_rule_poc" {
  name           = "chargebee_retention-eventbridge-to-firehose-rule_poc"
  event_bus_name = aws_cloudwatch_event_bus.chargebee_retention_event_bus_poc.name
  event_pattern = jsonencode({
    "id" : [{
      "exists" : true
    }]
  })
}

# EventBridge Target for Firehose
resource "aws_cloudwatch_event_target" "chargebee_retention_eventbridge_to_firehose_target_poc" {
  rule           = aws_cloudwatch_event_rule.chargebee_retention_eventbridge_to_firehose_rule_poc.name
  arn            = aws_kinesis_firehose_delivery_stream.chargebee_retention_firehose_to_s3_poc.arn
  role_arn       = aws_iam_role.chargebee_retention_eventbridge_firehose_role_poc.arn
  event_bus_name = aws_cloudwatch_event_bus.chargebee_retention_event_bus_poc.name
}

# EventBridge Target for CloudWatch Logs
resource "aws_cloudwatch_event_target" "chargebee_retention_eventbridge_to_log_target_poc" {
  rule           = aws_cloudwatch_event_rule.chargebee_retention_eventbridge_to_firehose_rule_poc.name
  arn            = aws_cloudwatch_log_group.chargebee_retention_event_bus_logs_poc.arn
  # role_arn       = aws_iam_role.chargebee_retention_eventbridge_to_cloudwatch_role_poc.arn
  event_bus_name = aws_cloudwatch_event_bus.chargebee_retention_event_bus_poc.name
  depends_on     = [aws_cloudwatch_log_group.chargebee_retention_event_bus_logs_poc]
}

# Firehose Delivery Stream
resource "aws_kinesis_firehose_delivery_stream" "chargebee_retention_firehose_to_s3_poc" {
  name        = "chargebee_retention-firehose-to-s3_poc"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn            = aws_iam_role.chargebee_retention_eventbridge_firehose_role_poc.arn
    bucket_arn          = "arn:aws:s3:::${var.martech_s3_bucket}"
    prefix              = "outbounds/chargebee_retention/"
    error_output_prefix = "errors/chargebee_retention/"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.chargebee_retention_firehose_to_s3_logs_poc.name
      log_stream_name = aws_cloudwatch_log_stream.chargebee_retention_firehose_to_s3_log_stream_poc.name
    }
  }
}

resource "aws_cloudwatch_log_group" "chargebee_retention_firehose_to_s3_logs_poc" {
  name              = "/aws/kinesisfirehose/chargebee_retention_firehose_to_s3_poc"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_stream" "chargebee_retention_firehose_to_s3_log_stream_poc" {
  name           = "chargebee_retention_firehose_to_s3_log_stream_poc"
  log_group_name = aws_cloudwatch_log_group.chargebee_retention_firehose_to_s3_logs_poc.name
}
