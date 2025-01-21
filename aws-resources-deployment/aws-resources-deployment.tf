module "aws-s3-bucket" {
  source = "./aws-resources-deployment/aws-s3-bucket/"
}

module "aws-apigateway-s3" {
  source = "./aws-resources-deployment/aws-apigateway-s3/"
}

module "aws-lambda-function" {
  source = "./aws-resources-deployment/aws-lambda-function/"
}

module "aws-apigateway-eventbridge-firehose-s3" {
  source = "./aws-resources-deployment/aws-apigateway-eventbridge-firehose-s3/"
}