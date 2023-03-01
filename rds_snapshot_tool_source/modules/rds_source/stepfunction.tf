
resource "aws_sfn_state_machine" "state_machine_take_snapshots_rds" {
  name     = "take-snapshots-rds"
  role_arn = aws_iam_role.iamrole_state_execution.arn

  definition = <<EOF
{
  "Comment": "Triggers snapshot backup for RDS instances",
  "StartAt": "TakeSnapshots",
  "States": {
    "TakeSnapshots": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.lambda_take_snapshots_rds.arn}",
      "Next": "ShareSnapshot",
      "Retry": [
        {
          "ErrorEquals": [
            "SnapshotToolException"
          ],
          "IntervalSeconds": 300,
          "MaxAttempts": 20,
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
      ]
    },
    "ShareSnapshot": {
      "Type": "Task",
      "Resource": "arn:aws:states:::states:startExecution",
      "Parameters": {
        "StateMachineArn": "${aws_sfn_state_machine.statemachine_share_snapshots_rds.arn}",
        "Input": {
          "NeedCallback": false,
          "AWS_STEP_FUNCTIONS_STARTED_BY_EXECUTION_ID.$": "$$.Execution.Id"
        }
      },
      "End": true
    }
  }
}
EOF 
}

resource "aws_sfn_state_machine" "statemachine_share_snapshots_rds" {
  name     = "share-snapshots-rds"
  role_arn = aws_iam_role.iamrole_state_execution.arn

  definition = <<EOF
{
	"Comment": "Shares snapshots with DEST_ACCOUNT",
	"StartAt": "ShareSnapshots",
	"States": {
		"ShareSnapshots": {
			"Type": "Task",
			"Resource": "${aws_lambda_function.lambda_share_snapshots_rds.arn}",
			"Retry": [
				{
					"ErrorEquals": [
						"SnapshotToolException"
					],
					"IntervalSeconds": 300,
					"MaxAttempts": 3,
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

resource "aws_sfn_state_machine" "statemachine_delete_old_snapshots_rds" {
  name     = "delete-old-snapshots-source-rds"
  role_arn = aws_iam_role.iamrole_state_execution.arn

  definition = <<EOF
{
	"Comment": "DeleteOld for RDS snapshots in source region",
	"StartAt": "DeleteOldDestRegion",
	"States": {
		"DeleteOldDestRegion": {
			"Type": "Task",
			"Resource": "${aws_lambda_function.lambda_delete_snapshots_rds.arn}",
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
