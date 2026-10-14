output "data_bucket" {
  value = aws_s3_bucket.data.bucket
}

output "ingestion_function" {
  value = aws_lambda_function.ingestion.function_name
}

output "transformation_function" {
  value = aws_lambda_function.transformation.function_name
}

output "athena_workgroup" {
  value = aws_athena_workgroup.main.name
}