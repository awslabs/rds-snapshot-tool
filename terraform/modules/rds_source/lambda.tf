
resource "aws_lambda_function" "lambda_take_snapshots_rds" {
  code_signing_config_arn = {
    S3Bucket = var.code_bucket
    S3Key    = "take_snapshots_rds.zip"
  }
  memory_size = 512
  description = "This functions triggers snapshots creation for RDS instances. It checks for existing snapshots following the pattern and interval specified in the environment variables with the following format: <dbinstancename>-YYYY-MM-DD-HH-MM"
  environment {
    variables = {
      INTERVAL        = var.backup_interval
      PATTERN         = var.instance_name_pattern
      LOG_LEVEL       = var.log_level
      REGION_OVERRIDE = var.source_region_override
      TAGGEDINSTANCE  = var.tagged_instance
    }
  }
  role    = aws_iam_role.iamrole_snapshots_rds.arn
  runtime = "python3.7"
  handler = "lambda_function.lambda_handler"
  timeout = 300
}

resource "aws_lambda_function" "lambda_share_snapshots_rds" {
  count = locals.Share ? 1 : 0
  code_signing_config_arn = {
    S3Bucket = var.code_bucket
    S3Key    = "share_snapshots_rds.zip"
  }
  memory_size = 512
  description = "This function shares snapshots created by the take_snapshots_rds function with DEST_ACCOUNT specified in the environment variables. "
  environment {
    variables = {
      DEST_ACCOUNT    = var.destination_account
      LOG_LEVEL       = var.log_level
      PATTERN         = var.instance_name_pattern
      REGION_OVERRIDE = var.source_region_override
    }
  }
  role    = aws_iam_role.iamrole_snapshots_rds.arn
  runtime = "python3.7"
  handler = "lambda_function.lambda_handler"
  timeout = 300
}

resource "aws_lambda_function" "lambda_delete_old_snapshots_rds" {
  count = locals.DeleteOld ? 1 : 0
  code_signing_config_arn = {
    S3Bucket = var.code_bucket
    S3Key    = "delete_old_snapshots_rds.zip"
  }
  memory_size = 512
  description = "This function deletes snapshots created by the take_snapshots_rds function. "
  environment {
    variables = {
      RETENTION_DAYS  = var.retention_days
      PATTERN         = var.instance_name_pattern
      LOG_LEVEL       = var.log_level
      REGION_OVERRIDE = var.source_region_override
    }
  }
  role    = aws_iam_role.iamrole_snapshots_rds.arn
  runtime = "python3.7"
  handler = "lambda_function.lambda_handler"
  timeout = 300
}
