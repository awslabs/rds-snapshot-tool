variable "code_bucket" {
  description = "Name of the bucket that contains the lambda functions to deploy."
  type        = string
  default     = "code-bucket-for-snapshot-sharing-12398127398172"
}

variable "instance_name_pattern" {
  description = "Python regex for matching cluster identifiers to backup. Use 'ALL_INSTANCES' to back up every RDS instance in the region."
  type        = string
  default     = "ALL_INSTANCES"
}

variable "backup_interval" {
  description = "Interval for backups in hours. Default is 24"
  type        = string
  default     = "24"
}

variable "destination_account" {
  description = "Destination account with no dashes."
  type        = string
  default     = ""
}

variable "share_snapshots" {
  type    = string
  default = "TRUE"
}

variable "backup_schedule" {
  description = "Backup schedule in Cloudwatch Event cron format. Needs to run at least once for every Interval. The default value runs once every at 1AM UTC. More information: http://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html"
  type        = string
  default     = "0 1 * * ? *"
}

variable "retention_days" {
  description = "Number of days to keep snapshots in retention before deleting them"
  type        = string
  default     = "7"
}

variable "log_level" {
  description = "Log level for Lambda functions (DEBUG, INFO, WARN, ERROR, CRITICAL are valid values)."
  type        = string
  default     = "ERROR"
}

variable "lambda_cw_log_retention" {
  description = "Number of days to retain logs from the lambda functions in CloudWatch Logs"
  type        = string
  default     = "7"
}

variable "source_region_override" {
  description = "Set to the region where your RDS instances run, only if such region does not support Step Functions. Leave as NO otherwise"
  type        = string
  default     = "NO"
}

variable "delete_old_snapshots" {
  description = "Set to TRUE to enable deletion of snapshot based on RetentionDays. Set to FALSE to disable"
  type        = string
  default     = "TRUE"
}

variable "tagged_instance" {
  description = "Set to TRUE to filter instances that have tag CopyDBSnapshot set to True. Set to FALSE to disable"
  type        = string
  default     = "FALSE"
}

variable "log_group_name" {
  description = "Name for RDS snapshot log group."
  type        = string
  default     = "lambdaDeleteOldSnapshotsRDS-source"
}

