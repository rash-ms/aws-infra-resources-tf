module "aws-s3-bucket" {
  source = "../aws-data-infrastructure/aws-s3-bucket/"
}

module "aws-apigateway-s3" {
  source = "../aws-data-infrastructure/aws-apigateway-s3/"
}

module "aws-lambda-function" {
  source = "../aws-data-infrastructure/aws-lambda-function/"
}

module "aws-apigateway-eventbridge-firehose-s3" {
  source = "../aws-data-infrastructure/aws-apigateway-eventbridge-firehose-s3/"
}