resource "aws_sns_topic" "copy_failed_dest" {
  display_name = "copies_failed_dest_rds"
}
resource "aws_sns_topic" "delete_old_failed_dest" {
  display_name = "delete_old_failed_dest_rds"
}

resource "aws_sns_topic_policy" "copy_failed_dest" {
  arn = aws_sns_topic.copy_failed_dest.arn // in tf there is not a cfn "topcs" attribute which allows a list. 

  policy = jsonencode({
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
  })
}

resource "aws_sns_topic_policy" "delete_failed_dest" {
  arn = aws_sns_topic.delete_old_failed_dest.arn // in tf there is not a cfn "topcs" attribute which allows a list. 

  policy = jsonencode({
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
  })
}

resource "aws_sns_topic_policy" "snspolicy_copy_failed_dest" {
  arn = aws_sns_topic.copy_failed_dest.arn

  policy = jsonencode({
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
  })
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
    StateMachineArn = aws_sfn_state_machine.statemachine_copy_old_snapshots_dest_rds.arn
  }

  alarm_description = "This metric monitors state machine failure for copying snapshots"
  alarm_actions = [
    aws_sns_topic.copy_failed_dest.id
  ]
}

resource "aws_cloudwatch_metric_alarm" "alarmcw_delete_old_failed_dest" {
  count               = local.DeleteOld ? 1 : 0
  alarm_name          = "failed-rds-delete-old-snapshot"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = "3600"
  statistic           = "Sum"
  threshold           = "2.0"

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.statemachine_delete_old_snapshots_dest_rds[*].arn
  }

  alarm_description = "This metric monitors state machine failure for deleting old snapshots"
  alarm_actions = [
    aws_sns_topic.delete_old_failed_dest.id
  ]
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
  rule      = aws_cloudwatch_event_rule.copy_snapshots_rds.name
  target_id = "DestTarget1"
  arn       = aws_sfn_state_machine.statemachine_copy_old_snapshots_dest_rds.id
  role_arn  = aws_iam_role.iamrole_step_invocation.arn
}

resource "aws_cloudwatch_event_rule" "delete_old_snapshots_rds" {
  name                = "trigger-snapshot-delete-in-dest-account"
  description         = "Triggers the RDS DeleteOld state machine in the destination account"
  schedule_expression = "cron(0 /1 * * ? *)"
  is_enabled          = true
}

resource "aws_cloudwatch_event_target" "delete_old_snapshots_rds" {
  count     = local.DeleteOld ? 1 : 0
  rule      = aws_cloudwatch_event_rule.delete_old_snapshots_rds.name
  target_id = "DestTarget1"
  arn       = aws_sfn_state_machine.statemachine_delete_old_snapshots_dest_rds[0].id
  role_arn  = aws_iam_role.iamrole_step_invocation.arn
}

resource "aws_cloudwatch_log_group" "cwloggroup_delete_old_snapshots_dest_rds" {
  count             = local.DeleteOld ? 1 : 0
  name              = "/aws/lambda/${var.log_group_name}"
  retention_in_days = var.lambda_cw_log_retention
}


resource "aws_cloudwatch_log_group" "copy_snapshots_rds" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_copy_snapshots_rds.function_name}"
  retention_in_days = var.lambda_cw_log_retention
}
