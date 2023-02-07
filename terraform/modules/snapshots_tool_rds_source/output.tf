output "backup_failed_topic" {
  description = "Subscribe to this topic to receive alerts of failed backups"
  value = aws_sns_topic.topic_backups_failed.id
}

output "share_failed_topic" {
  description = "Subscribe to this topic to receive alerts of failures at sharing snapshots with destination account"
  value = aws_sns_topic.topic_share_failed.id
}

output "delete_old_failed_topic" {
  description = "Subscribe to this topic to receive alerts of failures at deleting old snapshots"
  value = aws_sns_topic.topic_delete_old_failed.id
}

output "source_url" {
  description = "For more information and documentation, see the source repository at GitHub."
  value = "https://github.com/awslabs/rds-snapshot-tool"
}

