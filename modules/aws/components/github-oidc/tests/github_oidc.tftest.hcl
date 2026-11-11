mock_provider "aws" {}

variables {
  name_prefix = "acme-test-github"
}

run "rejects_unscoped_trust" {
  command = plan

  variables {
    roles = {
      bad = {
        description = "Trusts every repository on GitHub"
        subjects    = ["*"]
      }
    }
  }

  expect_failures = [var.roles]
}

run "creates_scoped_roles" {
  command = plan

  variables {
    roles = {
      deploy = {
        description         = "Deploy"
        subjects            = ["repo:acme/infrastructure:environment:staging"]
        managed_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
      }
    }
  }

  assert {
    condition     = keys(aws_iam_role.this) == ["deploy"] && aws_iam_role.this["deploy"].name == "acme-test-github-deploy"
    error_message = "Roles are named <prefix>-<key>."
  }
}
