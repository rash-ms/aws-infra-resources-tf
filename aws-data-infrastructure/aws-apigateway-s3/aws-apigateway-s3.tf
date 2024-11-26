# API Gateway Deployment updated to depend on the stage
resource "aws_api_gateway_deployment" "spain_sub_apigateway_s3_deployment" {

  # Use triggers to force deployment
  triggers = {
    # stage_description = md5(file("${path.module}/api-resources-resources.tf"))
    stage_description = "${md5(file("api-resources-resources.tf"))}"
  }

  # stage_description = "API deployment for stage dev - ${timestamp()}" 

  # rest_api_id = "${aws_api_gateway_rest_api.spain_sub_apigateway_shopify_flow_rest_api.id}"
  rest_api_id = aws_api_gateway_rest_api.spain_sub_apigateway_shopify_flow_rest_api.id
  
  depends_on = [
    aws_api_gateway_method.spain_sub_apigateway_create_method,
    aws_api_gateway_integration.spain_sub_apigateway_s3_integration_request,
    aws_api_gateway_integration_response.spain_sub_apigateway_s3_integration_response,
    aws_api_gateway_method_response.spain_sub_apigateway_s3_method_response
  ]
}
