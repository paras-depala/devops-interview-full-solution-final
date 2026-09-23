output "aws_role_arn" {
  description = "Put this ARN in the AWS_ROLE_ARN repo variable so GitHub Actions can deploy."
  value       = aws_iam_role.deploy.arn
}

output "aws_plan_role_arn" {
  description = "The role used for PR plans. Copy its ARN into AWS_PLAN_ROLE_ARN."
  value       = aws_iam_role.plan.arn
}

output "tf_state_bucket" {
  description = "This bucket holds the Terraform state. Use its name for TF_STATE_BUCKET."
  value       = aws_s3_bucket.state.id
}

output "aws_region" {
  description = "Region to use for AWS_REGION."
  value       = var.aws_region
}
