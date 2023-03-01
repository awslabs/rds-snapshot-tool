locals {
  Share = var.share_snapshots == "TRUE"
  DeleteOld = var.delete_old_snapshots == "TRUE"
}

