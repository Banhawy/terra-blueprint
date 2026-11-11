mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["eu-central-1a", "eu-central-1b", "eu-central-1c"] }
  }
  mock_data "aws_region" {
    defaults = { region = "eu-central-1" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

variables {
  name = "acme-test"
  cidr = "10.10.0.0/16"
}

run "three_tiers_without_overlap" {
  command = plan

  assert {
    condition     = [for s in aws_subnet.public : s.cidr_block] == ["10.10.0.0/24", "10.10.1.0/24"]
    error_message = "Public subnets are /24s at the start of the range."
  }

  assert {
    condition     = [for s in aws_subnet.private : s.cidr_block] == ["10.10.16.0/20", "10.10.32.0/20"]
    error_message = "Private subnets are /20s."
  }

  assert {
    condition     = [for s in aws_subnet.database : s.cidr_block] == ["10.10.128.0/24", "10.10.129.0/24"]
    error_message = "Database subnets are /24s from 10.x.128.0."
  }
}

run "nat_per_az_by_default" {
  command = plan

  assert {
    condition     = length(aws_nat_gateway.this) == 2
    error_message = "One NAT gateway per AZ unless single_nat_gateway is set."
  }
}

run "single_nat_for_cost" {
  command = plan

  variables {
    single_nat_gateway         = true
    enable_interface_endpoints = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1 && length(aws_vpc_endpoint.interface) == 0
    error_message = "Cost mode: one NAT gateway, no interface endpoints."
  }
}

run "rejects_tiny_cidr" {
  command = plan

  variables {
    cidr = "10.10.0.0/24"
  }

  expect_failures = [var.cidr]
}
