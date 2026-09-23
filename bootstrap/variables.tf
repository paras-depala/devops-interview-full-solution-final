variable "name" {
  description = "The app name goes into the bucket and role names. Keep it the same in infra."
  type        = string
  default     = "node-web-api"
}

variable "aws_region" {
  description = "Where to create the state bucket."
  type        = string
  default     = "eu-west-2"
}

variable "github_repository" {
  description = <<-EOT
    GitHub repo allowed to deploy. Match the repo value in the OIDC subject claim.
    This can be owner/name or owner@owner-id/name@repo-id.
  EOT
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+(@[0-9]+)?/[A-Za-z0-9_.-]+(@[0-9]+)?$", var.github_repository))
    error_message = "github_repository must be owner/name or owner@owner-id/name@repo-id, without wildcards."
  }
}
