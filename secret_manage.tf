data "aws_iam_policy_document" "argocd" {

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
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/SDSDevOpsEc2BastionHostRole",
        # "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AWSGSDevRole",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AWSGSDevOpsRole",
      ])
    }

    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.argocd.arn]
  }
  statement {
    sid    = "AdminRole"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = setunion(var.condition_values, [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/SDSDevOpsEc2BastionHostRole",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AWSGSDevOpsRole",
      ])
    }

    actions   = ["secretsmanager:*"]
    resources = [aws_secretsmanager_secret.argocd.arn]
  }
}

data "aws_iam_policy_document" "grafana" {

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
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/SDSDevOpsEc2BastionHostRole",
        # "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AWSGSDevRole",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AWSGSDevOpsRole",
      ])
    }

    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.grafana.arn]
  }
  statement {
    sid    = "AdminRole"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = setunion(var.condition_values, [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/SDSDevOpsEc2BastionHostRole",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AWSGSDevOpsRole",
      ])
    }

    actions   = ["secretsmanager:*"]
    resources = [aws_secretsmanager_secret.grafana.arn]
  }
}
# [ ARGO CD Secretsmanage & Password]
resource "random_password" "argocd" {
  count = var.enable_argocd ? 1 : 0
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name                    = "${var.tags["Service"]}-${var.tags["System"]}-argocd-${var.environment}-scm-${random_string.default.result}"
  recovery_window_in_days = 0
  tags = merge(var.tags, {
    Name = "${var.tags["Service"]}-${var.tags["System"]}-argocd-${var.environment}-scm-${random_string.default.result}"
  })
}

resource "aws_secretsmanager_secret_policy" "argocd" {
  count = var.enable_argocd ? 1 : 0

  secret_arn = aws_secretsmanager_secret.argocd.arn
  policy     = data.aws_iam_policy_document.argocd.json
}

resource "aws_secretsmanager_secret_version" "argocd" {
  count = var.enable_argocd ? 1 : 0

  secret_id     = aws_secretsmanager_secret.argocd.id
  secret_string = random_password.argocd.result
}

# # [ Grafana Secretsmanage & Password]
resource "random_password" "grafana" {
  count = var.enable_kube_prometheus_stack ? 1 : 0

  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "grafana" {
  count = var.enable_kube_prometheus_stack ? 1 : 0

  name                    = "${var.tags["Service"]}-${var.tags["System"]}-grafana-${var.environment}-scm-${random_string.default.result}"
  recovery_window_in_days = 0
  tags = merge(var.tags, {
    Name = "${var.tags["Service"]}-${var.tags["System"]}-grafana-${var.environment}-scm-${random_string.default.result}"
  })
}

resource "aws_secretsmanager_secret_policy" "grafana" {
  count = var.enable_kube_prometheus_stack ? 1 : 0

  secret_arn = aws_secretsmanager_secret.grafana.arn
  policy     = data.aws_iam_policy_document.grafana.json
}

resource "aws_secretsmanager_secret_version" "grafana" {
  count = var.enable_kube_prometheus_stack ? 1 : 0

  secret_id     = aws_secretsmanager_secret.grafana.id
  secret_string = random_password.grafana.result
}


