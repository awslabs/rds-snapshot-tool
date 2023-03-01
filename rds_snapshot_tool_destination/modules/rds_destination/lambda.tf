resource "aws_lambda_function" "delete_old_dest_rds" {
  function_name = "dest-snapshot-retention"
  description   = "This function enforces retention on the snapshots shared with the destination account. "
  s3_bucket     = var.code_bucket
  s3_key        = local.CrossAccount ? "delete_old_snapshots_dest_rds.zip" : "delete_old_snapshots_no_x_account_rds.zip"
  memory_size   = 512

  environment {
    variables = {
      SNAPSHOT_PATTERN = var.snapshot_pattern
      DEST_REGION      = var.destination_region
      RETENTION_DAYS   = var.retention_days
      LOG_LEVEL        = var.log_level
    }
  }
  role    = aws_iam_role.snapshots_rds.arn
  runtime = "python3.7"
  handler = "lambda_function.lambda_handler"
  timeout = 300
}


resource "aws_lambda_function" "lambda_copy_snapshots_rds" {
  function_name = "snapshot-copier"
  description   = "This functions copies snapshots for RDS Instances shared with this account. It checks for existing snapshots following the pattern specified in the environment variables with the following format: <dbInstanceIdentifier-identifier>-YYYY-MM-DD-HH-MM"
  s3_bucket     = var.code_bucket
  s3_key        = local.CrossAccount ? "copy_snapshots_dest_rds.zip" : "copy_snapshots_no_x_account_rds.zip"
  memory_size   = 512
  environment {
    variables = {
      SNAPSHOT_PATTERN      = var.snapshot_pattern
      DEST_REGION           = var.destination_region
      LOG_LEVEL             = var.log_level
      REGION_OVERRIDE       = var.source_region_override
      KMS_KEY_DEST_REGION   = var.kms_key_destination
      KMS_KEY_SOURCE_REGION = var.kms_key_source
      RETENTION_DAYS        = var.retention_days
    }
  }
  role    = aws_iam_role.snapshots_rds.arn
  runtime = "python3.7"
  handler = "lambda_function.lambda_handler"
  timeout = 300
}
