output "copy_failed_topic" {
  description = "Subscribe to this topic to receive alerts of failed copies"
  value       = aws_sns_topic.topic_copy_failed_dest.id
}

output "delete_old_failed_topic" {
  description = "Subscribe to this topic to receive alerts of failures at deleting old snapshots"
  value       = aws_sns_topic.topic_delete_old_failed_dest.id
}

output "source_url" {
  description = "For more information and documentation, see the source repository at GitHub."
  value       = "https://github.com/awslabs/rds-snapshot-tool"
}
