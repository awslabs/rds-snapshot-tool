variable "code_bucket" {
  description = "Name of the bucket that contains the lambda functions to deploy."
  type        = string
  default     = ""
}

variable "snapshot_pattern" {
  description = "Python regex for matching instance names to backup. Use 'ALL_SNAPSHOTS' to back up every RDS instance in the region."
  type        = string
  default     = "ALL_SNAPSHOTS"
}

variable "retention_days" {
  description = "Number of days to keep snapshots in retention before deleting them"
  type        = string
  default     = "7"
}

variable "destination_region" {
  description = "Destination region for snapshots."
  type        = string
  default     = "us-east-2"
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

variable "kms_key_destination" {
  description = "Set to the ARN for the KMS key in the destination region to re-encrypt encrypted snapshots. Leave None if you are not using encryption"
  type        = string
  default     = "None"
}

variable "kms_key_source" {
  description = "Set to the ARN for the KMS key in the SOURCE region to re-encrypt encrypted snapshots. Leave None if you are not using encryption"
  type        = string
  default     = "None"
}

variable "delete_old_snapshots" {
  description = "Set to TRUE to enable deletion of snapshot based on RetentionDays. Set to FALSE to disable"
  type        = string
  default     = "TRUE"
}

variable "cross_account_copy" {
  description = "Enable copying snapshots across accounts. Set to FALSE if your source snapshosts are not on a different account"
  type        = string
  default     = "TRUE"
}

variable "log_group_name" {
  description = "Name for RDS snapshot log group."
  type        = string
  default     = "lambdaDeleteOldSnapshotsRDS-dest"
}
