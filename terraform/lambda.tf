data "archive_file" "ingestion" {
  type        = "zip"
  source_dir  = "${path.module}/../src/ingestion"
  output_path = "${path.module}/build/ingestion.zip"
}

data "archive_file" "transformation" {
  type        = "zip"
  source_dir  = "${path.module}/../src/transformation"
  output_path = "${path.module}/build/transformation.zip"
}

resource "aws_lambda_function" "ingestion" {
  function_name    = "${var.project_name}-ingestion"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.ingestion.output_path
  source_code_hash = data.archive_file.ingestion.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      DATA_BUCKET = aws_s3_bucket.data.bucket
    }
  }
}

resource "aws_lambda_function" "transformation" {
  function_name    = "${var.project_name}-transformation"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.transformation.output_path
  source_code_hash = data.archive_file.transformation.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      DATA_BUCKET = aws_s3_bucket.data.bucket
    }
  }
}