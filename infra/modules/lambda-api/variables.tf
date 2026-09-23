variable "name" {
  description = "The function and API share this name."
  type        = string
}

variable "source_dir" {
  description = "Point this at the app folder, with production dependencies already installed."
  type        = string
}

variable "subnet_ids" {
  description = "Lambda will run in these private subnets. Pass the subnet IDs."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs to attach to Lambda."
  type        = list(string)
}

variable "environment_variables" {
  description = "Anything the app needs in its environment."
  type        = map(string)
  default     = {}
}

variable "secret_arns" {
  description = "Only these secrets can be read by Lambda. Takes a list of ARNs."
  type        = list(string)
}

variable "iam_role_path" {
  description = "The Lambda role goes under this IAM path, which the deploy role needs permission to manage."
  type        = string
}

variable "permissions_boundary_arn" {
  description = "Permissions boundary ARN for the Lambda role."
  type        = string
}

variable "memory_size" {
  description = "How much memory Lambda gets, in MB. More memory gives it more CPU too."
  type        = number
  default     = 256
}

variable "timeout" {
  description = "Stop the function after this many seconds."
  type        = number
  default     = 20
}

variable "throttling_rate_limit" {
  description = "Throttle the API above this many requests per second."
  type        = number
  default     = 50
}

variable "throttling_burst_limit" {
  description = "How many requests to allow in a burst."
  type        = number
  default     = 100
}
