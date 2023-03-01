// sns topic policy 

data "aws_iam_policy_document" "failed_dest" {

  statement {
    sid = "sns-permissions"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    effect = "Allow"
    actions = [
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
    resources = [
      "*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}



// failure on copy 
resource "aws_sns_topic" "copy_failed_dest" {
  display_name = "copies_failed_dest_rds"
}

resource "aws_sns_topic_policy" "copy_failed_dest" {
  policy = data.aws_iam_policy_document.failed_dest.json
  arn    = aws_sns_topic.copy_failed_dest.arn
}


/// failure on delete 
resource "aws_sns_topic" "delete_old_failed_dest" {
  display_name = "delete_old_failed_dest_rds"
}

resource "aws_sns_topic_policy" "delete_failed_dest" {
  policy = data.aws_iam_policy_document.failed_dest.json
  arn    = aws_sns_topic.delete_old_failed_dest.arn
}

