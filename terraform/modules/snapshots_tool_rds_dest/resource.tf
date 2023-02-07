resource "aws_sns_topic" "topic_copy_failed_dest" {
  display_name = "copies_failed_dest_rds"
}
resource "aws_sns_topic" "topic_delete_old_failed_dest" {
  display_name = "delete_old_failed_dest_rds"
}

resource "aws_sns_topic_policy" "snspolicy_delete_failed_dest" {
  arn = aws_sns_topic.topic_delete_old_failed_dest.arn // in tf there is not a cfn "topcs" attribute which allows a list. 

  policy = {
    Version = "2008-10-17"
    Id      = "destination_rds_failed_snapshot_delete"
    Statement = [
      {
        Sid    = "sns-permissions"
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
          test     = "StringEquals"
          variable = "AWS:SourceOwner"
          values   = [data.aws_caller_identity.current.account_id]
        }
      }
    ]
  }
}


resource "aws_sns_topic_policy" "snspolicy_copy_failed_dest" {
  arn = aws_sns_topic.topic_copy_failed_dest.arn

  policy = {
    Version = "2008-10-17"
    Id      = "destination_rds_failed_snapshot_copy"
    Statement = [
      {
        Sid    = "sns-permissions"
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
          test     = "StringEquals"
          variable = "AWS:SourceOwner"
          values   = [data.aws_caller_identity.current.account_id]
        }
      }
    ]
  }
}

resource "aws_cloudwatch_metric_alarm" "alarmcw_copy_failed_dest" {
  alarm_name          = "failed-rds-copy"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1.0"

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.statemachine_copy_snapshots_dest_rds.id
  }

  alarm_description = "This metric monitors state machine failure for copying snapshots"
  alarm_actions = [
    aws_sns_topic.topic_copy_failed_dest.id
  ]
}

resource "aws_cloudwatch_metric_alarm" "alarmcw_delete_old_failed_dest" {
  alarm_name          = "failed-rds-delete-old-snapshot"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = "3600"
  statistic           = "Sum"
  threshold           = "2.0"

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.statemachine_copy_snapshots_dest_rds.id
  }

  alarm_description = "This metric monitors state machine failure for deleting old snapshots"
  alarm_actions = [
    aws_sns_topic.topic_delete_old_failed_dest.id
  ]
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
            Sid    = "AllowUseOfTheKey"
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
            Sid    = "AllowAttachmentOfPersistentResources"
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
              test     = "Bool"
              variable = "kms:GrantIsForAWSResource"
              values   = ["True"]
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
    S3Key    = local.CrossAccount ? "copy_snapshots_dest_rds.zip" : "copy_snapshots_no_x_account_rds.zip"
  }
  memory_size = 512
  description = "This functions copies snapshots for RDS Instances shared with this account. It checks for existing snapshots following the pattern specified in the environment variables with the following format: <dbInstanceIdentifier-identifier>-YYYY-MM-DD-HH-MM"
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
  role    = aws_iam_role.iamrole_snapshots_rds.arn
  runtime = "python3.7"
  handler = "lambda_function.lambda_handler"
  timeout = 300
}

resource "aws_lambda_function" "lambda_delete_old_dest_rds" {
  count = locals.DeleteOld ? 1 : 0
  code_signing_config_arn = {
    S3Bucket = var.code_bucket
    S3Key    = local.CrossAccount ? "delete_old_snapshots_dest_rds.zip" : "delete_old_snapshots_no_x_account_rds.zip"
  }
  memory_size = 512
  description = "This function enforces retention on the snapshots shared with the destination account. "
  environment {
    variables = {
      SNAPSHOT_PATTERN = var.snapshot_pattern
      DEST_REGION      = var.destination_region
      RETENTION_DAYS   = var.retention_days
      LOG_LEVEL        = var.log_level
    }
  }
  role    = aws_iam_role.iamrole_snapshots_rds.arn
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

resource "aws_sfn_state_machine" "statemachine_delete_old_snapshots_dest_rds" {
  name     = "delete-old-snapshots-destination-rds"
  role_arn = aws_iam_role.iamrole_state_execution.arn

  definition = <<EOF
{
  "Comment": "DeleteOld for RDS snapshots in destination region",
  "StartAt": "DeleteOldDestRegion",
  "States": {
    "DeleteOldDestRegion": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.lambda_delete_old_dest_rds.arn}",
      "Retry": [
        {
          "ErrorEquals": [
            "SnapshotToolException"
          ],
          "IntervalSeconds": 600,
          "MaxAttempts": 5,
          "BackoffRate": 1
        },
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "IntervalSeconds": 30,
          "MaxAttempts": 20,
          "BackoffRate": 1
        }
      ],
      "End": true
    }
  }
}
EOF 
}

resource "aws_sfn_state_machine" "statemachine_copy_old_snapshots_dest_rds" {
  name     = "copy-old-snapshots-destination-rds"
  role_arn = aws_iam_role.iamrole_state_execution.arn

  definition = <<EOF
{
  "Comment": "Copies snapshots locally and then to DEST_REGION",
  "StartAt": "CopySnapshots",
  "States": {
    "CopySnapshots": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.lambda_copy_snapshots_rds.arn}",
      "Retry": [
        {
          "ErrorEquals": [
            "SnapshotToolException"
          ],
          "IntervalSeconds": 600,
          "MaxAttempts": 5,
          "BackoffRate": 1
        },
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "IntervalSeconds": 30,
          "MaxAttempts": 20,
          "BackoffRate": 1
        }
      ],
      "End": true
    }
  }
}
EOF 
}


resource "aws_iam_role" "iamrole_step_invocation" {
  name = "invoke-state-machines"
  assume_role_policy = jsonencode({
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
  })
  force_detach_policies = true
  inline_policy {
    name = "inline_policy_state_invocation"
    policy = jsonencode({
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
    })
  }
}


resource "aws_cloudwatch_event_rule" "copy_snapshots_rds" {
  name                = "capture-snapshot-copy-cw-events"
  description         = "Capture all CW state change events and triggers RDS copy state machine in destination account"
  schedule_expression = "cron(30 * * * ? *)"
  is_enabled          = true


  event_pattern = <<PATTERN
{
  "source": [
    "aws.cloudwatch"
  ],
  "detail-type": [
    "CloudWatch Alarm State Change"
  ],
  "resources": [
    "${aws_cloudwatch_metric_alarm.alarmcw_copy_failed_dest.arn}"
  ]
}
PATTERN
}

resource "aws_cloudwatch_event_target" "copy_snapshots_rds" {
  rule      = aws_cloudwatch_event_rule.dest_copy_events.name
  target_id = "DestTarget1"
  arn       = ws_sfn_state_machine.statemachine_copy_snapshots_dest_rds.id
  role_arn  = aws_iam_role.iamrole_step_invocation.arn
}

# resource "aws_iot_topic_rule_destination" "cw_event_delete_old_snapshots_rds" {
#   count = locals.DeleteOld ? 1 : 0
#   // CF Property(Description) = "Triggers the RDS DeleteOld state machine in the destination account"
#   // CF Property(ScheduleExpression) = join("", ["cron(", "0 /1 * * ? *", ")"])
#   // CF Property(State) = "ENABLED"
#   // CF Property(Targets) = [
#   //   {
#   //     Arn = aws_sfn_state_machine.statemachine_delete_old_snapshots_dest_rds[0].id
#   //     Id = "Target1"
#   //     RoleArn = aws_iam_role.iamrole_step_invocation.arn
#   //   }
#   // ]
# }

# resource "aws_inspector_resource_group" "cwloggroup_delete_old_snapshots_dest_rds" {
#   count = locals.DeleteOld ? 1 : 0
#   // CF Property(RetentionInDays) = var.lambda_cw_log_retention
#   // CF Property(LogGroupName) = "/aws/lambda/${var.log_group_name}"
# }

resource "aws_cloudwatch_log_group" "copy_snapshots_rds" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_copy_snapshots_rds.arn}"
  retention_in_days = var.lambda_cw_log_retention
}
