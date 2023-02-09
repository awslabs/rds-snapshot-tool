
resource "aws_lambda_function" "lambda_take_snapshots_rds" {
  function_name = "take-rds-snapshots"
  s3_bucket     = var.code_bucket
  s3_key        = "take_snapshots_rds.zip"
  memory_size   = 512
  description   = "This functions triggers snapshots creation for RDS instances. It checks for existing snapshots following the pattern and interval specified in the environment variables with the following format: <dbinstancename>-YYYY-MM-DD-HH-MM"
  environment {
    variables = {
      INTERVAL        = var.backup_interval
      PATTERN         = var.instance_name_pattern
      LOG_LEVEL       = var.log_level
      REGION_OVERRIDE = var.source_region_override
      TAGGEDINSTANCE  = var.tagged_instance
    }
  }
  role    = aws_iam_role.snapshots_rds.arn
  runtime = "python3.7"
  handler = "lambda_function.lambda_handler"
  timeout = 300
}

resource "aws_lambda_function" "lambda_share_snapshots_rds" {
  count         = local.Share ? 1 : 0
  function_name = "share-rds-snapshot"
  s3_bucket     = var.code_bucket
  s3_key        = "share_snapshots_rds.zip"
  memory_size   = 512
  description   = "This function shares snapshots created by the take_snapshots_rds function with DEST_ACCOUNT specified in the environment variables. "
  environment {
    variables = {
      DEST_ACCOUNT    = var.destination_account
      LOG_LEVEL       = var.log_level
      PATTERN         = var.instance_name_pattern
      REGION_OVERRIDE = var.source_region_override
    }
  }
  role    = aws_iam_role.snapshots_rds.arn
  runtime = "python3.7"
  handler = "lambda_function.lambda_handler"
  timeout = 300
}

resource "aws_lambda_function" "lambda_delete_snapshots_rds" {
  count         = local.DeleteOld ? 1 : 0
  function_name = "delete-old-rds-snapshots"
  s3_bucket     = var.code_bucket
  s3_key        = "delete_old_snapshots_rds.zip"
  memory_size   = 512
  description   = "This function deletes snapshots created by the take_snapshots_rds function. "
  environment {
    variables = {
      RETENTION_DAYS  = var.retention_days
      PATTERN         = var.instance_name_pattern
      LOG_LEVEL       = var.log_level
      REGION_OVERRIDE = var.source_region_override
    }
  }
  role    = aws_iam_role.snapshots_rds.arn
  runtime = "python3.7"
  handler = "lambda_function.lambda_handler"
  timeout = 300
}
