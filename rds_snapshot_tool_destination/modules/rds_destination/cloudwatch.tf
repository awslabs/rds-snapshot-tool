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
  alarm_name          = "failed-rds-delete-old-snapshot"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = "3600"
  statistic           = "Sum"
  threshold           = "2.0"

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.statemachine_delete_old_snapshots_dest_rds.arn
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
  rule      = aws_cloudwatch_event_rule.delete_old_snapshots_rds.name
  target_id = "DestTarget1"
  arn       = aws_sfn_state_machine.statemachine_delete_old_snapshots_dest_rds.id
  role_arn  = aws_iam_role.iamrole_step_invocation.arn
}

resource "aws_cloudwatch_log_group" "cwloggroup_delete_old_snapshots_dest_rds" {
  name              = "/aws/lambda/${var.log_group_name}"
  retention_in_days = var.lambda_cw_log_retention
}


resource "aws_cloudwatch_log_group" "copy_snapshots_rds" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_copy_snapshots_rds.function_name}"
  retention_in_days = var.lambda_cw_log_retention
}
