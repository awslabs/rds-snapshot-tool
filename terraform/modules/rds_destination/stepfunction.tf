
resource "aws_sfn_state_machine" "statemachine_delete_old_snapshots_dest_rds" {
  count    = local.DeleteOld ? 1 : 0
  name     = "delete-old-snapshots-destination-rds"
  role_arn = aws_iam_role.iamrole_state_execution.arn

  definition = <<EOF
{
  "Comment": "DeleteOld for RDS snapshots in destination region",
  "StartAt": "DeleteOldDestRegion",
  "States": {
    "DeleteOldDestRegion": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.delete_old_dest_rds[*].arn}",
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
