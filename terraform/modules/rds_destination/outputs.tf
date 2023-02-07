output "copy_failed_topic" {
  description = "Subscribe to this topic to receive alerts of failed copies"
  value       = aws_sns_topic.copy_failed_dest.id
}

output "delete_old_failed_topic" {
  description = "Subscribe to this topic to receive alerts of failures at deleting old snapshots"
  value       = aws_sns_topic.delete_old_failed_dest.id
}
