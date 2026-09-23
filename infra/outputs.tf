output "api_endpoint" {
  description = "Send API requests to this URL."
  value       = module.api.api_endpoint
}

output "lambda_function_name" {
  description = "Lambda function running the API."
  value       = module.api.function_name
}

output "lambda_alias_name" {
  description = "The pipeline points this alias at each new version, and back again if a deploy fails."
  value       = module.api.alias_name
}

output "lambda_version" {
  description = "Latest published version of the Lambda function."
  value       = module.api.version
}
