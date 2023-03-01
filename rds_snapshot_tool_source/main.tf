# This is an optional module to create a test DB instance if you don't have an existing one.

module "test_dbs" {
  source = "./modules/test_dbs"
}

module "snapshots_tool_rds_source" {
  source = "./modules/rds_source"
}
