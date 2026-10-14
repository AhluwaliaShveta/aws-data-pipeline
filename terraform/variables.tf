variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "agri-pipeline"
}

variable "alert_email" {
  type        = string
  description = "Email address for CloudWatch alarm notifications"
}