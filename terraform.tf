terraform {

  # Set the following environment variables, which Terraform will access in your build environment to configure both the AWS provider and the Terraform Cloud integration for your project:
  # Set AWS_ACCESS_KEY_I
  # Set AWS_SECRET_ACCESS_KEY
  # Set TF_CLOUD_ORGANIZATION
  # Set TF_WORKSPACE
  # Set TF_TOKEN_app_terraform_io
  cloud {
    organization = "jorgetovar"

    workspaces {
      name = "serverless-terraform"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1.0"
    }
  }
  required_version = "~> 1.2"
}