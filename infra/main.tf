terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.8"
    }
  }

  backend "s3" {
    key          = "node-web-api/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Application = var.name
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  iam_role_path            = "/${var.name}/"
  permissions_boundary_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.name}-lambda-boundary"
}

module "network" {
  source = "./modules/network"

  name       = var.name
  cidr_block = var.vpc_cidr
}

module "database" {
  source = "./modules/sql-server"

  name              = var.name
  subnet_ids        = module.network.private_subnet_ids
  security_group_id = module.network.database_security_group_id
  instance_class    = var.database_instance_class
}

module "api" {
  source = "./modules/lambda-api"

  name       = var.name
  source_dir = "${path.root}/../app"

  subnet_ids         = module.network.private_subnet_ids
  security_group_ids = [module.network.lambda_security_group_id]

  iam_role_path            = local.iam_role_path
  permissions_boundary_arn = local.permissions_boundary_arn
  secret_arns              = [module.database.master_user_secret_arn]

  environment_variables = {
    DB_HOST       = module.database.address
    DB_PORT       = tostring(module.database.port)
    DB_SECRET_ARN = module.database.master_user_secret_arn
  }
}
