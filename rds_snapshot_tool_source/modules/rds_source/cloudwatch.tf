
resource "aws_cloudwatch_metric_alarm" "alarmcw_backups_failed" {

  alarm_name          = "failed-rds-copy"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1.0"

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.state_machine_take_snapshots_rds.arn
  }

  alarm_description = ""
  alarm_actions = [
    aws_sns_topic.backups_failed.id
  ]
}

resource "aws_cloudwatch_metric_alarm" "alarmcw_share_failed" {
  alarm_name          = "failed-rds-share-snapshot"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = "3600"
  statistic           = "Sum"
  threshold           = "2.0"

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.statemachine_share_snapshots_rds.arn
  }

  alarm_description = ""
  alarm_actions = [
    aws_sns_topic.share_failed.id
  ]
}

resource "aws_cloudwatch_metric_alarm" "alarmcw_delete_old_failed" {
  alarm_name          = "failed-rds-delete-old-snapshot"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = "3600"
  statistic           = "Sum"
  threshold           = "2.0"

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.statemachine_delete_old_snapshots_rds.arn
  }

  alarm_description = ""
  alarm_actions = [
    aws_sns_topic.delete_old_failed.id
  ]
}

resource "aws_cloudwatch_event_rule" "backup_rds" {
  name                = "trigger-take-snapshot-state-machine"
  description         = "Triggers the TakeSnapshotsRDS state machine"
  schedule_expression = "cron(${var.backup_schedule})"
  is_enabled          = true
}

resource "aws_cloudwatch_event_target" "backup_rds" {
  rule      = aws_cloudwatch_event_rule.backup_rds.name
  target_id = "TakeSnapshotTarget1"
  arn       = aws_sfn_state_machine.state_machine_take_snapshots_rds.id
  role_arn  = aws_iam_role.iamrole_step_invocation.arn
}


### Uncomment to share the snapshots on a schedule ####
# resource "aws_cloudwatch_event_rule" "share_snapshots_rds" {
#   name                = "trigger-share-snapshot-state-machine"
#   description         = "Triggers the ShareSnapshotsRDS state machine"
#   schedule_expression = "cron(/10 * * * ? *)"
#   is_enabled          = true
# }

# resource "aws_cloudwatch_event_target" "share_snapshots_rds" {
#   rule      = aws_cloudwatch_event_rule.share_snapshots_rds.name
#   target_id = "ShareSnapshotTarget1"
#   arn       = aws_sfn_state_machine.statemachine_share_snapshots_rds.id
#   role_arn  = aws_iam_role.iamrole_step_invocation.arn
# }

resource "aws_cloudwatch_event_rule" "delete_old_snapshots_rds" {
  name                = "trigger-delete-snapshot-state-machine"
  description         = "Triggers the DeleteOldSnapshotsRDS state machine"
  schedule_expression = "cron(0 /1 * * ? *)"
  is_enabled          = true
}

resource "aws_cloudwatch_event_target" "delete_old_snapshots_rds" {
  rule      = aws_cloudwatch_event_rule.delete_old_snapshots_rds.name
  target_id = "DeleteSnapshotTarget1"
  arn       = aws_sfn_state_machine.statemachine_delete_old_snapshots_rds.id
  role_arn  = aws_iam_role.iamrole_step_invocation.arn
}

resource "aws_cloudwatch_log_group" "take_snapshots_rds" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_take_snapshots_rds.function_name}"
  retention_in_days = var.lambda_cw_log_retention
}


resource "aws_cloudwatch_log_group" "share_snapshots_rds" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_share_snapshots_rds.function_name}"
  retention_in_days = var.lambda_cw_log_retention
}

resource "aws_cloudwatch_log_group" "delete_old_snapshots_rds" {
  name              = "/aws/lambda/${var.log_group_name}"
  retention_in_days = var.lambda_cw_log_retention
}
