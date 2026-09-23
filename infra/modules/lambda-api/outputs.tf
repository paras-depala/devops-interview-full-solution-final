output "api_endpoint" {
  description = "The API is available at this URL."
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}

output "function_name" {
  description = "Name of the API's Lambda function."
  value       = aws_lambda_function.web_api.function_name
}

output "alias_name" {
  description = "API Gateway calls this alias."
  value       = aws_lambda_alias.live.name
}

output "version" {
  description = "Latest published version of the function."
  value       = aws_lambda_function.web_api.version
}
