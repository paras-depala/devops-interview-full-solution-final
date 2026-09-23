output "address" {
  description = "The app connects to the database using this hostname."
  value       = aws_db_instance.sql_server.address
}

output "port" {
  description = "Port SQL Server listens on."
  value       = aws_db_instance.sql_server.port
}

output "master_user_secret_arn" {
  description = "Use this secret ARN to fetch the database login. RDS manages the password."
  value       = aws_db_instance.sql_server.master_user_secret[0].secret_arn
}
