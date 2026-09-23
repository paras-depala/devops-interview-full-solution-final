variable "name" {
  description = "Use the same app name you gave bootstrap."
  type        = string
  default     = "node-web-api"
}

variable "aws_region" {
  description = "Where the app will run."
  type        = string
  default     = "eu-west-2"
}

variable "vpc_cidr" {
  description = "The address range to use for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "database_instance_class" {
  description = "Instance size for SQL Server."
  type        = string
  default     = "db.t3.medium"
}
