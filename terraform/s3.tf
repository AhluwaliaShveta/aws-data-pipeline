locals {
  data_bucket_name = "${var.project_name}-data-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "data" {
  bucket        = local.data_bucket_name
  force_destroy = true # lets destroy empty the bucket, including object versions. Learning project only.
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_lambda_permission" "s3_invoke_transformation" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transformation.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data.arn
}

# Only raw/ uploads trigger transformation. Without this filter, writing to
# processed/ would trigger the Lambda again and create an infinite loop.
resource "aws_s3_bucket_notification" "raw_created" {
  bucket = aws_s3_bucket.data.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.transformation.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "raw/"
  }

  depends_on = [aws_lambda_permission.s3_invoke_transformation]
}