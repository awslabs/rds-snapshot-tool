locals {
  DeleteOld    = var.delete_old_snapshots == "FALSE"
  CrossAccount = var.cross_account_copy == "FALSE"
}
