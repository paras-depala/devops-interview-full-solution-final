variable "name" {
  description = "The database and subnet group will use this name."
  type        = string
}

variable "subnet_ids" {
  description = "Give RDS private subnet IDs from at least two availability zones."
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for the database."
  type        = string
}

variable "engine" {
  description = "RDS SQL Server edition. Standard (sqlserver-se) needs db.t3.xlarge or larger."
  type        = string
  default     = "sqlserver-ex"
}

variable "engine_version" {
  description = "Use 16.00 for SQL Server 2022. RDS picks the minor version."
  type        = string
  default     = "16.00"
}

variable "instance_class" {
  description = "Database instance size."
  type        = string
  default     = "db.t3.medium"
}

variable "allocated_storage" {
  description = "How much disk space to allocate, in GiB. SQL Server needs at least 20."
  type        = number
  default     = 20
}

variable "multi_az" {
  description = "Turn this on for a standby in another AZ. Doesn't work with Express."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "How many days to keep backups."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "The database can't be deleted while this is on."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip the last snapshot when deleting the database."
  type        = bool
  default     = true
}
