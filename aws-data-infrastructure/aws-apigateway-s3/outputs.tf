output "role_apigateway_arn" {
  value = aws_iam_role.spain_sub_apigateway_s3_api_role.arn
}

output "role_apigateway_s3_policy_arn" {
  value = aws_iam_policy.spain_sub_apigateway_s3_iam_policy.arn
}

output "invoke_url" {
  value = aws_api_gateway_stage.spain_sub_apigateway_stage.invoke_url
}