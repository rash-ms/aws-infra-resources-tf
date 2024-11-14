output "teraform_aws_role_output" {
 value = aws_iam_role.spain_sub_shopify_flow_api_role.name
}

output "teraform_aws_role_arn_output" {
 value = aws_iam_role.spain_sub_shopify_flow_api_role.arn
}

output "teraform_logging_arn_output" {
 value = aws_iam_policy.spain_sub_shopify_flow_iam_policy.arn
}

# Output the API endpoint
output "api_endpoint" {
  value = "${aws_api_gateway_deployment.spain_sub_api_gateway_deployment.invoke_url}/contract"
}
