# # # output "role_output" {
# # #  value = aws_iam_role.spain_sub_api_gateway_s3_api_role.name
# # # }

# # # output "role_api_arn" {
# # #  value = aws_iam_role.spain_sub_api_gateway_s3_api_role.arn
# # # }

# # # output "role_policy_arn" {
# # #  value = aws_iam_policy.spain_sub_api_gateway_s3_iam_policy.arn
# # # }

# output "api_endpoint" {
#   value = "${aws_api_gateway_deployment.spain_sub_api_gateway_deployment.invoke_url}/{foldername}/{filename}"
# }