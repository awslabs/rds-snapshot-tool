resource "aws_sns_topic" "topic_backups_failed" {
  display_name = "backups_failed_rds"
}

resource "aws_sns_topic" "topic_share_failed" {
  display_name = "share_failed_rds"
}

resource "aws_sns_topic" "topic_delete_old_failed" {
  display_name = "delete_old_failed_rds"
}

resource "aws_sns_topic_policy" "snspolicy_snapshots_rds" {
  // CF Property(Topics) = [
  //   aws_sns_topic.topic_backups_failed.id,
  //   aws_sns_topic.topic_share_failed.id,
  //   aws_sns_topic.topic_delete_old_failed.id
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

resource "aws_cloudwatch_composite_alarm" "alarmcw_backups_failed" {
  actions_enabled = "true"
  // CF Property(ComparisonOperator) = "GreaterThanOrEqualToThreshold"
  // CF Property(EvaluationPeriods) = "1"
  // CF Property(MetricName) = "ExecutionsFailed"
  // CF Property(Namespace) = "AWS/States"
  // CF Property(Period) = "300"
  // CF Property(Statistic) = "Sum"
  // CF Property(Threshold) = "1.0"
  alarm_actions = [
    aws_sns_topic.topic_backups_failed.id
  ]
  // CF Property(Dimensions) = [
  //   {
  //     Name = "StateMachineArn"
  //     Value = aws_ec2_instance_state.state_machine_take_snapshots_rds.id
  //   }
  // ]
}

resource "aws_cloudwatch_composite_alarm" "alarmcw_share_failed" {
  count = locals.Share ? 1 : 0
  actions_enabled = "true"
  // CF Property(ComparisonOperator) = "GreaterThanOrEqualToThreshold"
  // CF Property(EvaluationPeriods) = "2"
  // CF Property(MetricName) = "ExecutionsFailed"
  // CF Property(Namespace) = "AWS/States"
  // CF Property(Period) = "3600"
  // CF Property(Statistic) = "Sum"
  // CF Property(Threshold) = "2.0"
  alarm_actions = [
    aws_sns_topic.topic_share_failed.id
  ]
  // CF Property(Dimensions) = [
  //   {
  //     Name = "StateMachineArn"
  //     Value = aws_ec2_instance_state.statemachine_share_snapshots_rds[0].id
  //   }
  // ]
}

resource "aws_cloudwatch_composite_alarm" "alarmcw_delete_old_failed" {
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
    aws_sns_topic.topic_delete_old_failed.id
  ]
  // CF Property(Dimensions) = [
  //   {
  //     Name = "StateMachineArn"
  //     Value = aws_ec2_instance_state.statemachine_delete_old_snapshots_rds[0].id
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
              "rds:ListTagsForResource",
              "rds:AddTagsToResource"
            ]
            Resource = "*"
          }
        ]
      }
    }
  ]
}

resource "aws_lambda_function" "lambda_take_snapshots_rds" {
  code_signing_config_arn = {
    S3Bucket = var.code_bucket
    S3Key = "take_snapshots_rds.zip"
  }
  memory_size = 512
  description = "This functions triggers snapshots creation for RDS instances. It checks for existing snapshots following the pattern and interval specified in the environment variables with the following format: <dbinstancename>-YYYY-MM-DD-HH-MM"
  environment {
    variables = {
      INTERVAL = var.backup_interval
      PATTERN = var.instance_name_pattern
      LOG_LEVEL = var.log_level
      REGION_OVERRIDE = var.source_region_override
      TAGGEDINSTANCE = var.tagged_instance
    }
  }
  role = aws_iam_role.iamrole_snapshots_rds.arn
  runtime = "python3.7"
  handler = "lambda_function.lambda_handler"
  timeout = 300
}

resource "aws_lambda_function" "lambda_share_snapshots_rds" {
  count = locals.Share ? 1 : 0
  code_signing_config_arn = {
    S3Bucket = var.code_bucket
    S3Key = "share_snapshots_rds.zip"
  }
  memory_size = 512
  description = "This function shares snapshots created by the take_snapshots_rds function with DEST_ACCOUNT specified in the environment variables. "
  environment {
    variables = {
      DEST_ACCOUNT = var.destination_account
      LOG_LEVEL = var.log_level
      PATTERN = var.instance_name_pattern
      REGION_OVERRIDE = var.source_region_override
    }
  }
  role = aws_iam_role.iamrole_snapshots_rds.arn
  runtime = "python3.7"
  handler = "lambda_function.lambda_handler"
  timeout = 300
}

resource "aws_lambda_function" "lambda_delete_old_snapshots_rds" {
  count = locals.DeleteOld ? 1 : 0
  code_signing_config_arn = {
    S3Bucket = var.code_bucket
    S3Key = "delete_old_snapshots_rds.zip"
  }
  memory_size = 512
  description = "This function deletes snapshots created by the take_snapshots_rds function. "
  environment {
    variables = {
      RETENTION_DAYS = var.retention_days
      PATTERN = var.instance_name_pattern
      LOG_LEVEL = var.log_level
      REGION_OVERRIDE = var.source_region_override
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
      PolicyName = "inline_policy_snapshots_rds"
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

resource "aws_ec2_instance_state" "state_machine_take_snapshots_rds" {
  // CF Property(DefinitionString) = join("", [join("
  // ", [" {"Comment":"Triggers snapshot backup for RDS instances",", " "StartAt":"TakeSnapshots",", " "States":{", "   "TakeSnapshots":{", "     "Type":"Task",", "     "Resource": "]), """, aws_lambda_function.lambda_take_snapshots_rds.arn, ""
  // ,", join("
  // ", ["     "Retry":[", "       {", "       "ErrorEquals":[ ", "         "SnapshotToolException"", "       ],", "       "IntervalSeconds":300,", "       "MaxAttempts":20,", "       "BackoffRate":1", "     },", "     {", "      "ErrorEquals":[ ", "         "States.ALL"], ", "         "IntervalSeconds": 30,", "         "MaxAttempts": 20,", "         "BackoffRate": 1", "     }", "    ],", "    "End": true ", "   }", " }}"])])
  // CF Property(RoleArn) = aws_iam_role.iamrole_state_execution.arn
}

resource "aws_ec2_instance_state" "statemachine_share_snapshots_rds" {
  count = locals.Share ? 1 : 0
  // CF Property(DefinitionString) = join("", [join("
  // ", [" {"Comment":"Shares snapshots with DEST_ACCOUNT",", " "StartAt":"ShareSnapshots",", " "States":{", "   "ShareSnapshots":{", "     "Type":"Task",", "     "Resource": "]), """, aws_lambda_function.lambda_share_snapshots_rds.arn, ""
  // ,", join("
  // ", ["     "Retry":[", "       {", "       "ErrorEquals":[ ", "         "SnapshotToolException"", "       ],", "       "IntervalSeconds":300,", "       "MaxAttempts":3,", "       "BackoffRate":1", "     },", "     {", "      "ErrorEquals":[ ", "         "States.ALL"], ", "         "IntervalSeconds": 30,", "         "MaxAttempts": 20,", "         "BackoffRate": 1", "     }", "    ],", "    "End": true ", "   }", " }}"])])
  // CF Property(RoleArn) = aws_iam_role.iamrole_state_execution.arn
}

resource "aws_ec2_instance_state" "statemachine_delete_old_snapshots_rds" {
  count = locals.DeleteOld ? 1 : 0
  // CF Property(DefinitionString) = join("", [join("
  // ", [" {"Comment":"DeleteOld management for RDS snapshots",", " "StartAt":"DeleteOld",", " "States":{", "   "DeleteOld":{", "     "Type":"Task",", "     "Resource": "]), """, aws_lambda_function.lambda_delete_old_snapshots_rds.arn, ""
  // ,", join("
  // ", ["     "Retry":[", "       {", "       "ErrorEquals":[ ", "         "SnapshotToolException"", "       ],", "       "IntervalSeconds":300,", "       "MaxAttempts":7,", "       "BackoffRate":1", "     },", "     {", "      "ErrorEquals":[ ", "         "States.ALL"], ", "         "IntervalSeconds": 30,", "         "MaxAttempts": 20,", "         "BackoffRate": 1", "     }", "    ],", "    "End": true ", "   }", " }}"])])
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

resource "aws_iot_topic_rule_destination" "cw_event_backup_rds" {
  // CF Property(Description) = "Triggers the TakeSnapshotsRDS state machine"
  // CF Property(ScheduleExpression) = join("", ["cron(", var.backup_schedule, ")"])
  // CF Property(State) = "ENABLED"
  // CF Property(Targets) = [
  //   {
  //     Arn = aws_ec2_instance_state.state_machine_take_snapshots_rds.id
  //     Id = "Target1"
  //     RoleArn = aws_iam_role.iamrole_step_invocation.arn
  //   }
  // ]
}

resource "aws_iot_topic_rule_destination" "cw_event_share_snapshots_rds" {
  count = locals.Share ? 1 : 0
  // CF Property(Description) = "Triggers the ShareSnapshotsRDS state machine"
  // CF Property(ScheduleExpression) = join("", ["cron(", "/10 * * * ? *", ")"])
  // CF Property(State) = "ENABLED"
  // CF Property(Targets) = [
  //   {
  //     Arn = aws_ec2_instance_state.statemachine_share_snapshots_rds[0].id
  //     Id = "Target1"
  //     RoleArn = aws_iam_role.iamrole_step_invocation.arn
  //   }
  // ]
}

resource "aws_iot_topic_rule_destination" "cw_event_delete_old_snapshots_rds" {
  count = locals.DeleteOld ? 1 : 0
  // CF Property(Description) = "Triggers the DeleteOldSnapshotsRDS state machine"
  // CF Property(ScheduleExpression) = join("", ["cron(", "0 /1 * * ? *", ")"])
  // CF Property(State) = "ENABLED"
  // CF Property(Targets) = [
  //   {
  //     Arn = aws_ec2_instance_state.statemachine_delete_old_snapshots_rds[0].id
  //     Id = "Target1"
  //     RoleArn = aws_iam_role.iamrole_step_invocation.arn
  //   }
  // ]
}

resource "aws_inspector_resource_group" "cwloggrouplambda_take_snapshots_rds" {
  // CF Property(RetentionInDays) = var.lambda_cw_log_retention
  // CF Property(LogGroupName) = "/aws/lambda/${aws_lambda_function.lambda_take_snapshots_rds.arn}"
}

resource "aws_inspector_resource_group" "cwloggrouplambda_share_snapshots_rds" {
  count = locals.Share ? 1 : 0
  // CF Property(RetentionInDays) = var.lambda_cw_log_retention
  // CF Property(LogGroupName) = "/aws/lambda/${aws_lambda_function.lambda_share_snapshots_rds[0].arn}"
}

resource "aws_inspector_resource_group" "cwloggrouplambda_delete_old_snapshots_rds" {
  // CF Property(RetentionInDays) = var.lambda_cw_log_retention
  // CF Property(LogGroupName) = "/aws/lambda/${var.log_group_name}"
}

