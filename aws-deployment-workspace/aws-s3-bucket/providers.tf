provider "aws" {
  alias  = "dev"
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::022499035568:role/byt-internal-workspace-dev-role"
  }
}

provider "aws" {
  alias  = "prod"
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::022499035568:role/byt-internal-workspace-prod-role"
  }
}