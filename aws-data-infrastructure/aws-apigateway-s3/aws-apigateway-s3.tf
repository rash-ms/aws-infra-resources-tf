resource "aws_api_gateway_deployment" "spain_sub_apigateway_s3_deployment" {

  # Use triggers to force deployment recreation when the file changes
  triggers = {
    stage_description = md5(file("${path.module}/aws-apigateway-resources.tf"))
  }

  stage_description = "API deployment for stage dev - ${timestamp()}" 

  # rest_api_id = aws_api_gateway_rest_api.spain_sub_apigateway_shopify_flow_rest_api.id
  rest_api_id = "${aws_api_gateway_rest_api.spain_sub_apigateway_shopify_flow_rest_api.id}"
  depends_on = [
    aws_api_gateway_method.spain_sub_apigateway_create_method,
    aws_api_gateway_integration.spain_sub_apigateway_s3_integration_request,
    aws_api_gateway_integration_response.spain_sub_apigateway_s3_integration_response,
    aws_api_gateway_method_response.spain_sub_apigateway_s3_method_response
  ]
}


# # Pass the dynamically generated prefix to the script
# resource "null_resource" "delete_old_logs" {
#   provisioner "local-exec" {
#     environment = {
#       LOG_GROUP_PREFIX = "/aws/apigateway/API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.spain_sub_apigateway_shopify_flow_rest_api.id}"
#     }
#     command = <<EOT
#       chmod +x ${path.module}/delete_old_logs.sh &&
#       ${path.module}/delete_old_logs.sh ${local.stage_name} $LOG_GROUP_PREFIX
#     EOT
#   }

#   triggers = {
#     stage_name = aws_api_gateway_stage.spain_sub_apigateway_stage.stage_name
#   }

#   depends_on = [aws_api_gateway_stage.spain_sub_apigateway_stage]
# }



