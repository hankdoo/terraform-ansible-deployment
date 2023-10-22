variable "aws_region" {
  description = "The AWS region"
}

variable "resource_tags" {
  description = "Tags to set for all resources"
  type        = map(string)
}
variable "container_port" {
  description = "container port"
  type        = number
}
variable "host_port" {
  description = "host port"
  type        = number
}
variable "memory" {
  description = "memory"
  type        = number
}
variable "cpu" {
  description = "cpu"
  type        = number
}
# variable "bucket_name" {
#   description = "The name of the S3 bucket. Must be globally unique."
#   type        = string
# }

# variable "access_key" {
#   description = "This is the AWS access key"
# }

# variable "secret_key" {
#   description = "This is the AWS secret key"
# }
