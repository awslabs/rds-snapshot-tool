locals {
  DeleteOld    = var.delete_old_snapshots == 0
  CrossAccount = var.cross_account_copy == 0
}
