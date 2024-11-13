resource "aws_iam_role" "spain_sub_shopify_flow_api_role" {
  name = "shopify_flow_role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      },
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "apigateway.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}

# IAM policy for logging from a lambda
resource "aws_iam_policy" "spain_sub_shopify_flow_iam_policy" {

  name         = "spain_sub_shopify_flow_iam_policy"
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
          "logs:PutLogEvents",
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "cloudwatch:Describe*"
        ],
        "Resource": "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Policy Attachment on the role.
resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role        = aws_iam_role.spain_sub_shopify_flow_api_role.name
  policy_arn  = aws_iam_policy.spain_sub_shopify_flow_iam_policy.arn
}

# Configure API Gateway account settings to use the CloudWatch Logs role
# resource "aws_api_gateway_account" "api_gateway_account" {
#   cloudwatch_role_arn = aws_iam_role.spain_sub_shopify_flow_api_role.arn
#   depends_on          = [aws_iam_role.spain_sub_shopify_flow_api_role, aws_iam_policy.spain_sub_shopify_flow_iam_policy]
# }


# Generates an archive from content, a file, or a directory of files.
# data "archive_file" "zip_the_python_code" {
#  type        = "zip"
#  source_dir  = "${path.module}/python/"
#  output_path = "${path.module}/python/lambda_handler.zip"
# }


# # Lambda Function
# resource "aws_lambda_function" "shopify_flow_func" {
#   filename       = "${path.module}/python/lambda_handler.zip"
#   source_code_hash = filebase64sha256("${path.module}/python/lambda_handler.zip")
#   function_name  = "Jhooq-Lambda-Function"
#   role           = aws_iam_role.spain_sub_shopify_flow_api_role.arn
#   handler        = "lambda_handler.lambda_handler"
#   runtime        = "python3.8"
#   depends_on     = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
# }


# # Get lambda code file from s3.
data "aws_s3_object" "lambda_code_versioned_object" {
  bucket = "byt-test-prod"
  key    = "spain_sub_lambda_file/spain_sub_function.zip"
}

# Lambda Function
resource "aws_lambda_function" "shopify_flow_func" {
  s3_bucket         = data.aws_s3_object.lambda_code_versioned_object.bucket  
  s3_key            = data.aws_s3_object.lambda_code_versioned_object.key
  s3_object_version = data.aws_s3_object.lambda_code_versioned_object.version_id  
  function_name     = "Spain-Sub-Shopify-Flow-Function"
  role              = aws_iam_role.spain_sub_shopify_flow_api_role.arn
  handler           = "spain_sub_function.lambda_handler"
  runtime           = "python3.8"
  depends_on        = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]

  environment {
    variables = {
      FIVETRAN_BUCKET_NAME = "byt_test_prod"
    }
  }
}


# REST API Gateway
resource "aws_api_gateway_rest_api" "spain_sub_shopify_flow_rest_api" {
  name        = "spain_sub_shopify_flow_rest_api"
  description = "REST API for Shopify Flow integration"
}


resource "aws_api_gateway_resource" "contract" {
  rest_api_id = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
  parent_id   = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.root_resource_id
  path_part   = "contract"
  depends_on  = [aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api]  
}

# Define GET method on "/subscriptions/contract"
resource "aws_api_gateway_method" "get_contract" {
  rest_api_id   = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
  resource_id   = aws_api_gateway_resource.contract.id
  http_method   = "GET"
  authorization = "NONE"
}

# Define POST method on "/subscriptions/contract"
resource "aws_api_gateway_method" "post_contract" {
  rest_api_id   = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
  resource_id   = aws_api_gateway_resource.contract.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integration for GET method with Lambda
resource "aws_api_gateway_integration" "lambda_get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
  resource_id             = aws_api_gateway_resource.contract.id
  http_method             = aws_api_gateway_method.get_contract.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.shopify_flow_func.invoke_arn
}

# Integration for POST method with Lambda
resource "aws_api_gateway_integration" "lambda_post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
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
  source_arn    = "${aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.execution_arn}/*"
}

# Deploy the API
resource "aws_api_gateway_deployment" "spain_sub_shopify_flow_deployment" {
  rest_api_id = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
  depends_on = [
    aws_api_gateway_integration.lambda_get_integration,
    aws_api_gateway_integration.lambda_post_integration
  ]
}

# CloudWatch log group for API Gateway logs
resource "aws_cloudwatch_log_group" "spain_sub_shopify_flow_api_gateway_logs" {
  name              = "/aws/apigateway/spain_sub_shopify_flow_rest_api"
  retention_in_days = 7
}

# Enable API Gateway logging for the stage
resource "aws_api_gateway_stage" "spain_sub_shopify_flow_stage_logs" {
  stage_name = "subscriptions"
  rest_api_id = aws_api_gateway_rest_api.spain_sub_shopify_flow_rest_api.id
  deployment_id = aws_api_gateway_deployment.spain_sub_shopify_flow_deployment.id

  # access_log_settings {
  #   destination_arn = aws_cloudwatch_log_group.spain_sub_shopify_flow_api_gateway_logs.arn
  #   format = jsonencode({
  #     "requestId"      = "$context.requestId",
  #     "ip"             = "$context.identity.sourceIp",
  #     "requestTime"    = "$context.requestTime",
  #     "domainName"     = "$context.domainName",
  #     "httpMethod"     = "$context.httpMethod",
  #     "routeKey"       = "$context.routeKey",
  #     "status"         = "$context.status",
  #     "protocol"       = "$context.protocol",
  #     "responseLength" = "$context.responseLength"
  #   })
  # }
}
