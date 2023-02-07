locals {
  DeleteOld    = var.delete_old_snapshots == "FALSE"
  CrossAccount = var.cross_account_copy == "FALSE"
  sns_topic_names = [
    "copies_failed_dest_rds",
    "delete_old_failed_dest_rds"
  ]
}
