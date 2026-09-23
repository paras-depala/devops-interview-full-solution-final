output "vpc_id" {
  description = "The app's VPC ID."
  value       = aws_vpc.application.id
}

output "private_subnet_ids" {
  description = "Use these subnet IDs for Lambda and the database."
  value       = values(aws_subnet.private)[*].id
}

output "lambda_security_group_id" {
  description = "Security group ID for Lambda."
  value       = aws_security_group.lambda.id
}

output "database_security_group_id" {
  description = "Attach this security group to the database to let Lambda connect."
  value       = aws_security_group.database.id
}
