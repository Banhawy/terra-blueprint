# -----------------------------------------------------------------------------
# Keyless CI: GitHub Actions assumes IAM roles with its OIDC token, so no AWS
# access keys exist anywhere. Each role trusts only the repository / branch /
# environment patterns listed in its `subjects`.
#
# The OIDC provider is account-wide (one per account); create it once and pass
# its ARN to other instances of this module with create_oidc_provider = false.
# -----------------------------------------------------------------------------

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.oidc_provider_arn
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "trust" {
  for_each = var.roles

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # e.g. repo:acme/infrastructure:environment:production
    #      repo:acme/infrastructure:pull_request
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = each.value.subjects
    }
  }
}

resource "aws_iam_role" "this" {
  for_each = var.roles

  name                 = "${var.name_prefix}-${each.key}"
  description          = each.value.description
  assume_role_policy   = data.aws_iam_policy_document.trust[each.key].json
  max_session_duration = each.value.max_session_duration
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = merge([
    for role, cfg in var.roles : {
      for arn in cfg.managed_policy_arns : "${role}|${arn}" => { role = role, arn = arn }
    }
  ]...)

  role       = aws_iam_role.this[each.value.role].name
  policy_arn = each.value.arn
}

# Keyed by role and policy *name*, which are always known at plan time even
# when the policy JSON is computed during apply.
resource "aws_iam_role_policy" "inline" {
  for_each = merge([
    for role, cfg in var.roles : {
      for name, json in cfg.inline_policies : "${role}|${name}" => { role = role, name = name, json = json }
    }
  ]...)

  name   = each.value.name
  role   = aws_iam_role.this[each.value.role].id
  policy = each.value.json
}
