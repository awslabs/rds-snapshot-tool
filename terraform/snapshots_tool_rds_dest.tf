data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  DeleteOld = var.delete_old_snapshots == "TRUE"
  CrossAccount = var.cross_account_copy == "TRUE"
}

variable "code_bucket" {
  description = "Name of the bucket that contains the lambda functions to deploy."
  type = string
}

variable "snapshot_pattern" {
  description = "Python regex for matching instance names to backup. Use "ALL_SNAPSHOTS" to back up every RDS instance in the region."
  type = string
  default = "ALL_SNAPSHOTS"
}

variable "retention_days" {
  description = "Number of days to keep snapshots in retention before deleting them"
  type = string
  default = "7"
}

variable "destination_region" {
  description = "Destination region for snapshots."
  type = string
}

variable "log_level" {
  description = "Log level for Lambda functions (DEBUG, INFO, WARN, ERROR, CRITICAL are valid values)."
  type = string
  default = "ERROR"
}

variable "lambda_cw_log_retention" {
  description = "Number of days to retain logs from the lambda functions in CloudWatch Logs"
  type = string
  default = "7"
}

variable "source_region_override" {
  description = "Set to the region where your RDS instances run, only if such region does not support Step Functions. Leave as NO otherwise"
  type = string
  default = "NO"
}

variable "kms_key_destination" {
  description = "Set to the ARN for the KMS key in the destination region to re-encrypt encrypted snapshots. Leave None if you are not using encryption"
  type = string
  default = "None"
}

variable "kms_key_source" {
  description = "Set to the ARN for the KMS key in the SOURCE region to re-encrypt encrypted snapshots. Leave None if you are not using encryption"
  type = string
  default = "None"
}

variable "delete_old_snapshots" {
  description = "Set to TRUE to enable deletion of snapshot based on RetentionDays. Set to FALSE to disable"
  type = string
  default = "TRUE"
}

variable "cross_account_copy" {
  description = "Enable copying snapshots across accounts. Set to FALSE if your source snapshosts are not on a different account"
  type = string
  default = "TRUE"
}

variable "log_group_name" {
  description = "Name for RDS snapshot log group."
  type = string
  default = "lambdaDeleteOldSnapshotsRDS-dest"
}

resource "aws_sns_topic" "topic_copy_failed_dest" {
  display_name = "copies_failed_dest_rds"
}

resource "aws_sns_topic" "topic_delete_old_failed_dest" {
  display_name = "delete_old_failed_dest_rds"
}

resource "aws_sns_topic_policy" "snspolicy_copy_failed_dest" {
  // CF Property(Topics) = [
  //   aws_sns_topic.topic_copy_failed_dest.id,
  //   aws_sns_topic.topic_delete_old_failed_dest.id
  // ]
  policy = {
    Version = "2008-10-17"
    Id = "__default_policy_ID"
    Statement = [
      {
        Sid = "__default_statement_ID"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "SNS:GetTopicAttributes",
          "SNS:SetTopicAttributes",
          "SNS:AddPermission",
          "SNS:RemovePermission",
          "SNS:DeleteTopic",
          "SNS:Subscribe",
          "SNS:ListSubscriptionsByTopic",
          "SNS:Publish",
          "SNS:Receive"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            AWS:SourceOwner = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  }
}

resource "aws_cloudwatch_composite_alarm" "alarmcw_copy_failed_dest" {
  actions_enabled = "true"
  // CF Property(ComparisonOperator) = "GreaterThanOrEqualToThreshold"
  // CF Property(EvaluationPeriods) = "1"
  // CF Property(MetricName) = "ExecutionsFailed"
  // CF Property(Namespace) = "AWS/States"
  // CF Property(Period) = "300"
  // CF Property(Statistic) = "Sum"
  // CF Property(Threshold) = "1.0"
  alarm_actions = [
    aws_sns_topic.topic_copy_failed_dest.id
  ]
  // CF Property(Dimensions) = [
  //   {
  //     Name = "StateMachineArn"
  //     Value = aws_ec2_instance_state.statemachine_copy_snapshots_dest_rds.id
  //   }
  // ]
}

resource "aws_cloudwatch_composite_alarm" "alarmcw_delete_old_failed_dest" {
  count = locals.DeleteOld ? 1 : 0
  actions_enabled = "true"
  // CF Property(ComparisonOperator) = "GreaterThanOrEqualToThreshold"
  // CF Property(EvaluationPeriods) = "2"
  // CF Property(MetricName) = "ExecutionsFailed"
  // CF Property(Namespace) = "AWS/States"
  // CF Property(Period) = "3600"
  // CF Property(Statistic) = "Sum"
  // CF Property(Threshold) = "2.0"
  alarm_actions = [
    aws_sns_topic.topic_delete_old_failed_dest.id
  ]
  // CF Property(Dimensions) = [
  //   {
  //     Name = "StateMachineArn"
  //     Value = aws_ec2_instance_state.statemachine_delete_old_snapshots_dest_rds[0].id
  //   }
  // ]
}

resource "aws_iam_role" "iamrole_snapshots_rds" {
  assume_role_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  }
  force_detach_policies = [
    {
      PolicyName = "inline_policy_snapshots_rds_cw_logs"
      PolicyDocument = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
            ]
            Resource = "arn:aws:logs:*:*:*"
          }
        ]
      }
    },
    {
      PolicyName = "inline_policy_snapshots_rds"
      PolicyDocument = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "rds:CreateDBSnapshot",
              "rds:DeleteDBSnapshot",
              "rds:DescribeDBInstances",
              "rds:DescribeDBSnapshots",
              "rds:ModifyDBSnapshotAttribute",
              "rds:DescribeDBSnapshotAttributes",
              "rds:CopyDBSnapshot",
              "rds:ListTagsForResource",
              "rds:AddTagsToResource"
            ]
            Resource = "*"
          }
        ]
      }
    },
    {
      PolicyName = "inline_policy_snapshot_rds_kms_access"
      PolicyDocument = {
        Version = "2012-10-17"
        Statement = [
          {
            Sid = "AllowUseOfTheKey"
            Effect = "Allow"
            Action = [
              "kms:Encrypt",
              "kms:Decrypt",
              "kms:ReEncrypt*",
              "kms:GenerateDataKey*",
              "kms:DescribeKey"
            ]
            Resource = [
              "*"
            ]
          },
          {
            Sid = "AllowAttachmentOfPersistentResources"
            Effect = "Allow"
            Action = [
              "kms:CreateGrant",
              "kms:ListGrants",
              "kms:RevokeGrant"
            ]
            Resource = [
              "*"
            ]
            Condition = {
              Bool = {
                kms:GrantIsForAWSResource = True
              }
            }
          }
        ]
      }
    }
  ]
}

resource "aws_lambda_function" "lambda_copy_snapshots_rds" {
  code_signing_config_arn = {
    S3Bucket = var.code_bucket
    S3Key = local.CrossAccount ? "copy_snapshots_dest_rds.zip" : "copy_snapshots_no_x_account_rds.zip"
  }
  memory_size = 512
  description = "This functions copies snapshots for RDS Instances shared with this account. It checks for existing snapshots following the pattern specified in the environment variables with the following format: <dbInstanceIdentifier-identifier>-YYYY-MM-DD-HH-MM"
  environment {
    variables = {
      SNAPSHOT_PATTERN = var.snapshot_pattern
      DEST_REGION = var.destination_region
      LOG_LEVEL = var.log_level
      REGION_OVERRIDE = var.source_region_override
      KMS_KEY_DEST_REGION = var.kms_key_destination
      KMS_KEY_SOURCE_REGION = var.kms_key_source
      RETENTION_DAYS = var.retention_days
    }
  }
  role = aws_iam_role.iamrole_snapshots_rds.arn
  runtime = "python3.7"
  handler = "lambda_function.lambda_handler"
  timeout = 300
}

resource "aws_lambda_function" "lambda_delete_old_dest_rds" {
  count = locals.DeleteOld ? 1 : 0
  code_signing_config_arn = {
    S3Bucket = var.code_bucket
    S3Key = local.CrossAccount ? "delete_old_snapshots_dest_rds.zip" : "delete_old_snapshots_no_x_account_rds.zip"
  }
  memory_size = 512
  description = "This function enforces retention on the snapshots shared with the destination account. "
  environment {
    variables = {
      SNAPSHOT_PATTERN = var.snapshot_pattern
      DEST_REGION = var.destination_region
      RETENTION_DAYS = var.retention_days
      LOG_LEVEL = var.log_level
    }
  }
  role = aws_iam_role.iamrole_snapshots_rds.arn
  runtime = "python3.7"
  handler = "lambda_function.lambda_handler"
  timeout = 300
}

resource "aws_iam_role" "iamrole_state_execution" {
  assume_role_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = join("", ["states.", data.aws_region.current.name, ".amazonaws.com"])
        }
        Action = "sts:AssumeRole"
      }
    ]
  }
  force_detach_policies = [
    {
      PolicyName = "inline_policy_rds_snapshot"
      PolicyDocument = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "lambda:InvokeFunction"
            ]
            Resource = "*"
          }
        ]
      }
    }
  ]
}

resource "aws_ec2_instance_state" "statemachine_copy_snapshots_dest_rds" {
  // CF Property(DefinitionString) = join("", [join("
  // ", [" {"Comment":"Copies snapshots locally and then to DEST_REGION",", " "StartAt":"CopySnapshots",", " "States":{", "   "CopySnapshots":{", "     "Type":"Task",", "     "Resource": "]), """, aws_lambda_function.lambda_copy_snapshots_rds.arn, ""
  // ,", join("
  // ", ["     "Retry":[", "       {", "       "ErrorEquals":[ ", "         "SnapshotToolException"", "       ],", "       "IntervalSeconds":300,", "       "MaxAttempts":5,", "       "BackoffRate":1", "     },", "     {", "      "ErrorEquals":[ ", "         "States.ALL"], ", "         "IntervalSeconds": 30,", "         "MaxAttempts": 20,", "         "BackoffRate": 1", "     }", "    ],", "    "End": true ", "   }", " }}"])])
  // CF Property(RoleArn) = aws_iam_role.iamrole_state_execution.arn
}

resource "aws_ec2_instance_state" "statemachine_delete_old_snapshots_dest_rds" {
  count = locals.DeleteOld ? 1 : 0
  // CF Property(DefinitionString) = join("", [join("
  // ", [" {"Comment":"DeleteOld for RDS snapshots in destination region",", " "StartAt":"DeleteOldDestRegion",", " "States":{", "   "DeleteOldDestRegion":{", "     "Type":"Task",", "     "Resource": "]), """, aws_lambda_function.lambda_delete_old_dest_rds.arn, ""
  // ,", join("
  // ", ["     "Retry":[", "       {", "       "ErrorEquals":[ ", "         "SnapshotToolException"", "       ],", "       "IntervalSeconds":600,", "       "MaxAttempts":5,", "       "BackoffRate":1", "     },", "     {", "      "ErrorEquals":[ ", "         "States.ALL"], ", "         "IntervalSeconds": 30,", "         "MaxAttempts": 20,", "         "BackoffRate": 1", "    }", "    ],", "    "End": true ", "   }", " }}"])])
  // CF Property(RoleArn) = aws_iam_role.iamrole_state_execution.arn
}

resource "aws_iam_role" "iamrole_step_invocation" {
  assume_role_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  }
  force_detach_policies = [
    {
      PolicyName = "inline_policy_state_invocation"
      PolicyDocument = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "states:StartExecution"
            ]
            Resource = "*"
          }
        ]
      }
    }
  ]
}

resource "aws_iot_topic_rule_destination" "cw_event_copy_snapshots_rds" {
  // CF Property(Description) = "Triggers the RDS Copy state machine in the destination account"
  // CF Property(ScheduleExpression) = join("", ["cron(", "/30 * * * ? *", ")"])
  // CF Property(State) = "ENABLED"
  // CF Property(Targets) = [
  //   {
  //     Arn = aws_ec2_instance_state.statemachine_copy_snapshots_dest_rds.id
  //     Id = "Target1"
  //     RoleArn = aws_iam_role.iamrole_step_invocation.arn
  //   }
  // ]
}

resource "aws_iot_topic_rule_destination" "cw_event_delete_old_snapshots_rds" {
  count = locals.DeleteOld ? 1 : 0
  // CF Property(Description) = "Triggers the RDS DeleteOld state machine in the destination account"
  // CF Property(ScheduleExpression) = join("", ["cron(", "0 /1 * * ? *", ")"])
  // CF Property(State) = "ENABLED"
  // CF Property(Targets) = [
  //   {
  //     Arn = aws_ec2_instance_state.statemachine_delete_old_snapshots_dest_rds[0].id
  //     Id = "Target1"
  //     RoleArn = aws_iam_role.iamrole_step_invocation.arn
  //   }
  // ]
}

resource "aws_inspector_resource_group" "cwloggroup_delete_old_snapshots_dest_rds" {
  count = locals.DeleteOld ? 1 : 0
  // CF Property(RetentionInDays) = var.lambda_cw_log_retention
  // CF Property(LogGroupName) = "/aws/lambda/${var.log_group_name}"
}

resource "aws_inspector_resource_group" "cwloggrouplambda_copy_snapshots_rds" {
  // CF Property(RetentionInDays) = var.lambda_cw_log_retention
  // CF Property(LogGroupName) = "/aws/lambda/${aws_lambda_function.lambda_copy_snapshots_rds.arn}"
}

output "copy_failed_topic" {
  description = "Subscribe to this topic to receive alerts of failed copies"
  value = aws_sns_topic.topic_copy_failed_dest.id
}

output "delete_old_failed_topic" {
  description = "Subscribe to this topic to receive alerts of failures at deleting old snapshots"
  value = aws_sns_topic.topic_delete_old_failed_dest.id
}

output "source_url" {
  description = "For more information and documentation, see the source repository at GitHub."
  value = "https://github.com/awslabs/rds-snapshot-tool"
}
