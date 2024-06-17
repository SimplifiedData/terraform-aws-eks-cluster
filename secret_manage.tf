
# [ ARGO CD Secretsmanage & Password]
resource "random_password" "default" {
  for_each = local.addon_enable_password ? var.addons_config_password : {}

  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "default" {
  for_each = local.addon_enable_password ? var.addons_config_password : {}

  name                    = try(each.value.name, "${each.key}-${var.environment != "dev" ? "scm" : "${var.environment}-scm-${var.name_service}-${random_string.default.result}"}")
  recovery_window_in_days = 0
  tags = merge(var.tags, {
    Name = try(each.value.name, "${each.key}-${var.environment != "dev" ? "scm" : "${var.environment}-scm"}")
  })
}

resource "aws_secretsmanager_secret_policy" "default" {
  for_each = local.addon_enable_password ? var.addons_config_password : {}

  secret_arn = aws_secretsmanager_secret.default[each.key].arn
  policy     = data.aws_iam_policy_document.scm_default[each.key].json
}

resource "aws_secretsmanager_secret_version" "default" {
  for_each = local.addon_enable_password ? var.addons_config_password : {}

  secret_id     = aws_secretsmanager_secret.default[each.key].id
  secret_string = random_password.default[each.key].result
}

data "aws_iam_policy_document" "scm_default" {
  for_each = local.addon_enable_password ? var.addons_config_password : {}

  statement {
    sid    = "AcceptRoleToReadTheSecret"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "StringNotLike"
      variable = "aws:PrincipalArn"
      values = setunion(var.condition_values, [
        # "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/SDSDevOpsEc2BastionHostRole",
        # "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AWSGSDevRole",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AWSGSDevOpsRole",
      ])
    }

    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.default[each.key].arn]
  }
  statement {
    sid    = "AdminRole"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = setunion(var.condition_values, [
        # "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/SDSDevOpsEc2BastionHostRole",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AWSGSDevOpsRole",
      ])
    }

    actions   = ["secretsmanager:*"]
    resources = [aws_secretsmanager_secret.default[each.key].arn]
  }
}
