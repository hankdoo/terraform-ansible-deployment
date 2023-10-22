output "lb_dns" {
  value       = aws_alb.aws_alb.dns_name
  description = "AWS load balancer DNS Name"
}
# output "s3_bucket_arn" {
#   value       = aws_s3_bucket.terraform_state.arn
#   description = "The ARN of the S3 bucket"
# }
