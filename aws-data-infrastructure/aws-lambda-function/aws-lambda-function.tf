resource "aws_iam_role" "shopify_flow_api_role" {
 name   = "shopify_flow_role"
 assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# IAM policy for logging from a lambda
resource "aws_iam_policy" "shopify_flow_iam_policy" {

  name         = "shopify_flow_iam_policy_role"
  path         = "/"
  description  = "AWS IAM Policy for managing aws lambda role"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        "Resource": [
          "arn:aws:s3:::byt-test-dev",
          "arn:aws:s3:::byt-test-dev/*",
          "arn:aws:s3:::byt-test-prod",
          "arn:aws:s3:::byt-test-prod/*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource": "*"
      }
    ]
  })
}

# Policy Attachment on the role.
resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role        = aws_iam_role.shopify_flow_api_role.name
  policy_arn  = aws_iam_policy.shopify_flow_iam_policy.arn
}

# Generates an archive from content, a file, or a directory of files.
data "archive_file" "zip_the_python_code" {
 type        = "zip"
 source_dir  = "${path.module}/python/"
 output_path = "${path.module}/python/lambda_handler.zip"
}


# Lambda Function
resource "aws_lambda_function" "shopify_flow_func" {
  filename       = "${path.module}/python/lambda_handler.zip"
  function_name  = "Jhooq-Lambda-Function"
  role           = aws_iam_role.shopify_flow_api_role.arn
  handler        = "lambda_handler.lambda_handler"
  runtime        = "python3.8"
  depends_on     = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
}

# REST API Gateway
resource "aws_api_gateway_rest_api" "shopify_flow_rest_api" {
  name        = "shopify_flow_rest_api"
  description = "REST API for Shopify Flow integration"
}

# Define a resource for "/subscriptions"
resource "aws_api_gateway_resource" "subscriptions" {
  rest_api_id = aws_api_gateway_rest_api.shopify_flow_rest_api.id
  parent_id   = aws_api_gateway_rest_api.shopify_flow_rest_api.root_resource_id
  path_part   = "subscriptions"
}

# Define a nested resource for "/subscriptions/contract"
resource "aws_api_gateway_resource" "contract" {
  rest_api_id = aws_api_gateway_rest_api.shopify_flow_rest_api.id
  parent_id   = aws_api_gateway_resource.subscriptions.id
  path_part   = "contract"
}

# Define GET method on "/subscriptions/contract"
resource "aws_api_gateway_method" "get_contract" {
  rest_api_id   = aws_api_gateway_rest_api.shopify_flow_rest_api.id
  resource_id   = aws_api_gateway_resource.contract.id
  http_method   = "GET"
  authorization = "NONE"
}

# Define POST method on "/subscriptions/contract"
resource "aws_api_gateway_method" "post_contract" {
  rest_api_id   = aws_api_gateway_rest_api.shopify_flow_rest_api.id
  resource_id   = aws_api_gateway_resource.contract.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integration for GET method with Lambda
resource "aws_api_gateway_integration" "lambda_get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.shopify_flow_rest_api.id
  resource_id             = aws_api_gateway_resource.contract.id
  http_method             = aws_api_gateway_method.get_contract.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.shopify_flow_func.invoke_arn
}

# Integration for POST method with Lambda
resource "aws_api_gateway_integration" "lambda_post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.shopify_flow_rest_api.id
  resource_id             = aws_api_gateway_resource.contract.id
  http_method             = aws_api_gateway_method.post_contract.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.shopify_flow_func.invoke_arn
}

# Lambda Permission for API Gateway to invoke the function
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.shopify_flow_func.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.shopify_flow_rest_api.execution_arn}/*"
}

# Deploy the API
resource "aws_api_gateway_deployment" "shopify_flow_deployment" {
  rest_api_id = aws_api_gateway_rest_api.shopify_flow_rest_api.id
  depends_on = [
    aws_api_gateway_integration.lambda_get_integration,
    aws_api_gateway_integration.lambda_post_integration
  ]
}

# Create a single stage for the REST API deployment
resource "aws_api_gateway_stage" "shopify_flow_stage" {
  deployment_id = aws_api_gateway_deployment.shopify_flow_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.shopify_flow_rest_api.id
  stage_name    = "subscriptions"  # Use "subscriptions" as the stage name
}

# CloudWatch log group for API Gateway logs
resource "aws_cloudwatch_log_group" "shopify_flow_api_gateway_logs" {
  name              = "/aws/apigateway/shopify_flow_rest_api"
  retention_in_days = 7
}

# Enable API Gateway logging for the stage
resource "aws_api_gateway_stage" "shopify_flow_stage_with_logs" {
  stage_name = "subscriptions"
  rest_api_id = aws_api_gateway_rest_api.shopify_flow_rest_api.id
  deployment_id = aws_api_gateway_deployment.shopify_flow_deployment.id

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.shopify_flow_api_gateway_logs.arn
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

# # Create a lambda function
# # In terraform ${path.module} is the current directory.
# resource "aws_lambda_function" "shopify_flow_func" {
#  filename                       = "${path.module}/python/lambda_handler.zip"
#  function_name                  = "Jhooq-Lambda-Function"
#  role                           = aws_iam_role.shopify_flow_api_role.arn
#  handler                        = "lambda_handler.lambda_handler"
#  runtime                        = "python3.8"
#  depends_on                     = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
# }

# # Create API Gateway
# resource "aws_apigatewayv2_api" "shopify_flow_http_api" {
#   name          = "shopify_flow_http_api"
#   protocol_type = "HTTP"
# }

# resource "aws_cloudwatch_log_group" "shopify_flow_api_gateway_logs" {
#     name = "/aws/apigateway/shopify_flow_http_api"
#     retention_in_days = 7
# }

# resource "aws_lambda_permission" "api_gateway_invoke" {
#   statement_id  = "AllowAPIGatewayInvoke"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.shopify_flow_func.function_name
#   principal     = "apigateway.amazonaws.com"
#   source_arn    = "${aws_apigatewayv2_api.shopify_flow_http_api.execution_arn}/*"
# }

# resource "aws_apigatewayv2_integration" "shopify_flow_api_integration" {
#   api_id           = aws_apigatewayv2_api.shopify_flow_http_api.id
#   integration_type = "AWS_PROXY"
#   integration_uri  = aws_lambda_function.shopify_flow_func.invoke_arn
# }

# resource "aws_apigatewayv2_route" "shopify_flow_route_get" {
#   api_id    = aws_apigatewayv2_api.shopify_flow_http_api.id
#   route_key = "GET /sub-contract"
#   target    = "integrations/${aws_apigatewayv2_integration.shopify_flow_api_integration.id}"
# }

# resource "aws_apigatewayv2_route" "shopify_flow_route_post" {
#   api_id    = aws_apigatewayv2_api.shopify_flow_http_api.id
#   route_key = "POST /sub-contract"
#   target    = "integrations/${aws_apigatewayv2_integration.shopify_flow_api_integration.id}"
# }

# resource "aws_apigatewayv2_stage" "shopify_flow_stage" {
#   api_id      = aws_apigatewayv2_api.shopify_flow_http_api.id
#   name        = "$default"
#   auto_deploy = true

#   access_log_settings {
#         destination_arn = aws_cloudwatch_log_group.shopify_flow_api_gateway_logs.arn
#         format = jsonencode({
#         "requestId"      = "$context.requestId",
#         "ip"             = "$context.identity.sourceIp",
#         "requestTime"    = "$context.requestTime",
#         "domainName"     = "$context.domainName",
#         "httpMethod"     = "$context.httpMethod",
#         "routeKey"       = "$context.routeKey",
#         "status"         = "$context.status",
#         "protocol"       = "$context.protocol",
#         "responseLength" = "$context.responseLength"
#         })
#     }
# }