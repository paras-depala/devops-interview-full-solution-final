mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "eu-west-2"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:eu-west-2:123456789012:log-group:test"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/test/test-lambda"
    }
  }

  mock_resource "aws_lambda_function" {
    defaults = {
      arn        = "arn:aws:lambda:eu-west-2:123456789012:function:test"
      invoke_arn = "arn:aws:apigateway:eu-west-2:lambda:path/2015-03-31/functions/arn:aws:lambda:eu-west-2:123456789012:function:test/invocations"
      version    = "1"
    }
  }

  mock_resource "aws_lambda_alias" {
    defaults = {
      arn        = "arn:aws:lambda:eu-west-2:123456789012:function:test:live"
      invoke_arn = "arn:aws:apigateway:eu-west-2:lambda:path/2015-03-31/functions/arn:aws:lambda:eu-west-2:123456789012:function:test:live/invocations"
    }
  }

  mock_resource "aws_apigatewayv2_api" {
    defaults = {
      execution_arn = "arn:aws:execute-api:eu-west-2:123456789012:abcdef1234"
    }
  }
}

mock_provider "archive" {}

run "database_is_private_and_encrypted" {
  command = plan

  module {
    source = "./modules/sql-server"
  }

  variables {
    name              = "test"
    subnet_ids        = ["subnet-a", "subnet-b"]
    security_group_id = "sg-database"
  }

  assert {
    condition     = !aws_db_instance.sql_server.publicly_accessible
    error_message = "The database must not be publicly accessible."
  }

  assert {
    condition     = aws_db_instance.sql_server.storage_encrypted && aws_db_instance.sql_server.manage_master_user_password
    error_message = "Storage must be encrypted and the master password managed by RDS."
  }

  assert {
    condition     = aws_db_instance.sql_server.vpc_security_group_ids == toset(["sg-database"])
    error_message = "The database must use only the security group it is given."
  }

  assert {
    condition     = aws_db_instance.sql_server.engine == "sqlserver-ex" && aws_db_instance.sql_server.instance_class == "db.t3.medium"
    error_message = "The default database must be SQL Server on db.t3.medium."
  }
}

run "only_lambda_can_reach_the_database" {
  module {
    source = "./modules/network"
  }

  variables {
    name       = "test"
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.database_from_lambda.referenced_security_group_id == aws_security_group.lambda.id &&
      aws_vpc_security_group_ingress_rule.database_from_lambda.from_port == 1433 &&
      aws_vpc_security_group_ingress_rule.database_from_lambda.to_port == 1433
    )
    error_message = "SQL Server must accept connections only from the Lambda security group on port 1433."
  }

  assert {
    condition     = length(distinct([for subnet in aws_subnet.private : subnet.availability_zone])) == 2
    error_message = "Private subnets must span two availability zones."
  }
}

run "lambda_role_is_bounded_and_function_is_private" {
  module {
    source = "./modules/lambda-api"
  }

  variables {
    name                     = "test"
    source_dir               = "../app"
    subnet_ids               = ["subnet-a", "subnet-b"]
    security_group_ids       = ["sg-lambda"]
    iam_role_path            = "/test/"
    permissions_boundary_arn = "arn:aws:iam::123456789012:policy/test-lambda-boundary"
    secret_arns              = ["arn:aws:secretsmanager:eu-west-2:123456789012:secret:rds!db-test"]
  }

  assert {
    condition     = aws_iam_role.lambda.permissions_boundary == var.permissions_boundary_arn && aws_iam_role.lambda.path == "/test/"
    error_message = "The execution role must carry the boundary and live under the application path."
  }

  assert {
    condition     = data.aws_iam_policy_document.read_secrets.statement[0].resources == toset(var.secret_arns)
    error_message = "The function may read only the secrets it is given."
  }

  assert {
    condition     = aws_lambda_function.web_api.vpc_config[0].subnet_ids == toset(var.subnet_ids)
    error_message = "The function must run in the private subnets."
  }

  assert {
    condition     = aws_lambda_permission.api_gateway.source_arn == "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
    error_message = "Only this API may invoke the function."
  }

  assert {
    condition = (
      aws_lambda_function.web_api.publish &&
      aws_apigatewayv2_integration.lambda.integration_uri == aws_lambda_alias.live.invoke_arn &&
      aws_lambda_permission.api_gateway.qualifier == aws_lambda_alias.live.name
    )
    error_message = "API Gateway must invoke the live alias of a published version, so a failed deploy can be rolled back."
  }
}
