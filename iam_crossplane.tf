#======================================#
# Crossplane IAM Role                  #
#======================================#
data "aws_iam_policy_document" "assume" {
  count = var.enable_crossplane ? 1 : 0

  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity",
    ]
    effect = "Allow"
    condition {
      test = "StringLike"
      values = [
        "system:serviceaccount:upbound-system:provider-*",
      ]
      variable = "${module.eks.oidc_provider}:sub"
    }
    condition {
      test     = "StringLike"
      variable = "${module.eks.oidc_provider}:aud"

      values = ["sts.amazonaws.com"]
    }
    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity",
    ]
    effect = "Allow"
    condition {
      test = "StringLike"
      values = [
        "system:serviceaccount:upbound-system:rbac-manager",
      ]
      variable = "${module.eks.oidc_provider}:sub"
    }
    condition {
      test     = "StringLike"
      variable = "${module.eks.oidc_provider}:aud"

      values = ["sts.amazonaws.com"]
    }
    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity",
    ]
    effect = "Allow"
    condition {
      test = "StringLike"
      values = [
        "system:serviceaccount:upbound-system:upbound-provider-*",
      ]
      variable = "${module.eks.oidc_provider}:sub"
    }
    condition {
      test     = "StringLike"
      variable = "${module.eks.oidc_provider}:aud"

      values = ["sts.amazonaws.com"]
    }
    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity",
    ]
    effect = "Allow"
    condition {
      test = "StringLike"
      values = [
        "system:serviceaccount:upbound-system:crossplane",
      ]
      variable = "${module.eks.oidc_provider}:sub"
    }
    condition {
      test     = "StringLike"
      variable = "${module.eks.oidc_provider}:aud"

      values = ["sts.amazonaws.com"]
    }
    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}
#data "aws_iam_policy_document" "additional" {}

resource "aws_iam_role" "crossplane" {
  count = var.enable_crossplane ? 1 : 0

  # name        = var.role_name_use_prefix ? null : local.role_name
  name_prefix = "${var.tags["Service"]}-${var.tags["System"]}-${var.environment}-crossplane-"
  path        = "/"
  description = "IAM Role for Crossplane"

  assume_role_policy    = data.aws_iam_policy_document.assume[0].json
  max_session_duration  = null
  permissions_boundary  = null
  force_detach_policies = true

  tags = merge(var.tags, {
    Name = "${var.tags["Service"]}-${var.tags["System"]}-${var.environment}-crossplane"
  })
}

resource "aws_iam_role_policy_attachment" "additional" {
  count = var.enable_crossplane ? 1 : 0

  role       = aws_iam_role.crossplane[0].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
