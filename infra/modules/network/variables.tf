variable "name" {
  description = "The VPC gets this name; the other network resources use it as a prefix."
  type        = string
}

variable "cidr_block" {
  description = "Choose the VPC address range. A /16 gives us /24 private subnets."
  type        = string
}
