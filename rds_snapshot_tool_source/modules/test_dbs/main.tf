resource "aws_db_instance" "source" {
  allocated_storage    = 10
  db_name              = "db_migration_source_db"
  identifier           = "db-migration-source-db"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  username             = "foo"
  password             = "foobarbaz"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
}

