
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
