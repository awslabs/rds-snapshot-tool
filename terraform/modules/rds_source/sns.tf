data "aws_iam_policy_document" "failed_source" {

  statement {
    sid = "__default_policy_ID"
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


resource "aws_sns_topic" "backups_failed" {
  display_name = "backups_failed_rds"
}

resource "aws_sns_topic_policy" "backups_failed" {
  policy = data.aws_iam_policy_document.failed_source.json
  arn    = aws_sns_topic.backups_failed.arn
}

resource "aws_sns_topic" "share_failed" {
  display_name = "share_failed_rds"
}

resource "aws_sns_topic_policy" "share_failed" {
  policy = data.aws_iam_policy_document.failed_source.json
  arn    = aws_sns_topic.share_failed.arn
}

resource "aws_sns_topic" "delete_old_failed" {
  display_name = "delete_old_failed_rds"
}

resource "aws_sns_topic_policy" "topic_delete_old_failed" {
  policy = data.aws_iam_policy_document.failed_source.json
  arn    = aws_sns_topic.delete_old_failed.arn
}
