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
    cost-center = "default"
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
  role_name                         = "lambda-${local.binary_name}"
  create_lambda_function_url        = true
  create_sam_metadata               = true
  cloudwatch_logs_retention_in_days = 14
  function_tags                     = local.tags
  cloudwatch_logs_tags              = local.tags
}


# ################################################################################
# # IAM external connections
# ################################################################################

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-hegerdes-publish-http-get-push"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
  tags               = local.tags
}

resource "aws_iam_policy" "github_actions" {
  name        = "github-actions-http-get-push"
  description = "Grant Github Actions the ability to push the labda code from hegerdes/publish"
  policy      = data.aws_iam_policy_document.github_actions.json
  tags        = local.tags
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:hegerdes/publish:*"]
    }
  }
}

data "aws_iam_policy_document" "github_actions" {
  statement {
    actions = [
      "s3:PutObject",
      "iam:ListRoles",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:GetFunctionConfiguration",
      "lambda:InvokeFunction",
      "lambda:CreateFunction",
      "lambda:GetFunction",
    ]
    resources = [module.lambda.lambda_function_arn]
  }

  statement {
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }
}
