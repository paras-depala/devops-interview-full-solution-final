data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

locals {
  subnet_cidrs = {
    for index, zone in slice(data.aws_availability_zones.available.names, 0, 2) :
    zone => cidrsubnet(var.cidr_block, 8, index)
  }
}

resource "aws_vpc" "application" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = var.name }
}

resource "aws_subnet" "private" {
  for_each = local.subnet_cidrs

  vpc_id            = aws_vpc.application.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = { Name = "${var.name}-private-${each.key}" }
}

resource "aws_security_group" "lambda" {
  name        = "${var.name}-lambda"
  description = "Web API Lambda function"
  vpc_id      = aws_vpc.application.id
}

resource "aws_security_group" "database" {
  name        = "${var.name}-database"
  description = "SQL Server, reachable only from the Lambda function"
  vpc_id      = aws_vpc.application.id
}

resource "aws_security_group" "endpoints" {
  name        = "${var.name}-endpoints"
  description = "Interface VPC endpoints"
  vpc_id      = aws_vpc.application.id
}

resource "aws_vpc_security_group_egress_rule" "lambda_to_database" {
  security_group_id            = aws_security_group.lambda.id
  referenced_security_group_id = aws_security_group.database.id
  ip_protocol                  = "tcp"
  from_port                    = 1433
  to_port                      = 1433
}

resource "aws_vpc_security_group_ingress_rule" "database_from_lambda" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.lambda.id
  ip_protocol                  = "tcp"
  from_port                    = 1433
  to_port                      = 1433
}

resource "aws_vpc_security_group_egress_rule" "lambda_to_endpoints" {
  security_group_id            = aws_security_group.lambda.id
  referenced_security_group_id = aws_security_group.endpoints.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_from_lambda" {
  security_group_id            = aws_security_group.endpoints.id
  referenced_security_group_id = aws_security_group.lambda.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_endpoint" "secrets_manager" {
  vpc_id              = aws_vpc.application.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = values(aws_subnet.private)[*].id
  security_group_ids  = [aws_security_group.endpoints.id]

  tags = { Name = "${var.name}-secretsmanager" }
}
