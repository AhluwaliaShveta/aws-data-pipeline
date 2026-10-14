resource "aws_athena_workgroup" "main" {
  name          = "${var.project_name}-wg"
  force_destroy = true

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.data.bucket}/athena-results/"
    }
  }
}