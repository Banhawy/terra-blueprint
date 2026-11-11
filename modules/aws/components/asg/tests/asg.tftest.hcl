mock_provider "aws" {
  mock_data "aws_ssm_parameter" {
    defaults = { value = "ami-0123456789abcdef0" }
  }
  mock_data "aws_default_tags" {
    defaults = { tags = { Project = "acme", Environment = "test" } }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

variables {
  name       = "acme-test-workers"
  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = ["subnet-a", "subnet-b"]
}

run "instances_are_hardened" {
  command = plan

  assert {
    condition     = one(aws_launch_template.this.metadata_options).http_tokens == "required"
    error_message = "IMDSv2 must be required."
  }

  assert {
    condition     = one(one(aws_launch_template.this.block_device_mappings).ebs).encrypted == "true"
    error_message = "Root volumes must be encrypted."
  }

  assert {
    condition     = aws_launch_template.this.key_name == null
    error_message = "No SSH key: access is through SSM Session Manager."
  }
}

run "default_tags_reach_instances" {
  command = plan

  assert {
    condition     = aws_launch_template.this.tag_specifications[0].tags["Project"] == "acme"
    error_message = "Provider default tags must be copied onto launched instances."
  }
}
