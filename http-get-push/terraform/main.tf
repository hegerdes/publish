terraform {
  required_version = ">=1.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.49.0"
    }
  }
}
# Configure the AWS Provider
provider "aws" {
  region  = "eu-central-1"
  profile = "aws-admin"
}

locals {
  src_path     = "${path.module}/../-nodesrc"
  binary_name  = "http-get-push"
  binary_path  = abspath("${path.module}/builds/${local.binary_name}")
  archive_path = "${local.binary_path}.zip"

  tags = {
    owner       = "Henrik Gerdes"
    cost-center = "unknown"
    project     = "http-get-push"
    status      = "active"
    managed-by  = "terraform"
    env         = "production"
    repository  = "https://github.com/hegerdes/publish"
  }
}

resource "null_resource" "lambda_build" {
  provisioner "local-exec" {
    command = "go build -mod=readonly -o ${local.binary_path}"
    environment = {
      GOOS        = "linux"
      GOARCH      = "amd64"
      CGO_ENABLED = 0
      GOFLAGS     = "-trimpath"
    }
    working_dir = "${path.module}/../go-src"
  }
}

module "lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.4.0"

  function_name                     = local.binary_name
  source_path                       = "${path.module}/../node-src"
  handler                           = "index.handler"
  description                       = "Perform a get request to post or put data."
  runtime                           = "nodejs20.x"
  architectures                     = ["arm64"]
  authorization_type                = "NONE"
  create_lambda_function_url        = true
  create_sam_metadata               = true
  cloudwatch_logs_retention_in_days = 14
  function_tags                     = local.tags
  cloudwatch_logs_tags              = local.tags
}
