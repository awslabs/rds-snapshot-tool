locals {
  DeleteOld    = var.delete_old_snapshots == "TRUE"
  CrossAccount = var.cross_account_copy == "TRUE"
}
