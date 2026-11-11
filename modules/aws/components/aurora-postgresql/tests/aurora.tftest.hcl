mock_provider "aws" {
  mock_data "aws_rds_engine_version" {
    defaults = { version = "17.5" }
  }
}

variables {
  name          = "acme-test-db"
  database_name = "app"
  vpc_id        = "vpc-0123456789abcdef0"
  subnet_ids    = ["subnet-a", "subnet-b"]
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = aws_rds_cluster.this.storage_encrypted
    error_message = "Storage must be encrypted."
  }

  assert {
    condition     = aws_rds_cluster.this.manage_master_user_password
    error_message = "The master password must be RDS-managed (never in state)."
  }

  assert {
    condition     = aws_rds_cluster.this.iam_database_authentication_enabled
    error_message = "IAM database authentication must be available."
  }
}

run "deletion_protection_keeps_a_final_snapshot" {
  command = plan

  variables {
    deletion_protection = true
  }

  assert {
    condition     = aws_rds_cluster.this.deletion_protection && !aws_rds_cluster.this.skip_final_snapshot
    error_message = "Protected clusters must also take a final snapshot."
  }
}
