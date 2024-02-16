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

resource "aws_iam_role_policy_attachment" "AWSGSBasePolicy" {
  count = var.enable_crossplane ? 1 : 0

  role       = aws_iam_role.crossplane[0].name
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/AWSGSBasePolicy"
}

resource "aws_iam_role_policy_attachment" "AWSGSComputeExtendPolicy" {
  count = var.enable_crossplane ? 1 : 0

  role       = aws_iam_role.crossplane[0].name
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/AWSGSComputeExtendPolicy"
}

resource "aws_iam_role_policy_attachment" "AWSGSComputeFullPolicy" {
  count = var.enable_crossplane ? 1 : 0

  role       = aws_iam_role.crossplane[0].name
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/AWSGSComputeFullPolicy"
}

resource "aws_iam_role_policy_attachment" "AWSGSDatabaseFullPolicy" {
  count = var.enable_crossplane ? 1 : 0

  role       = aws_iam_role.crossplane[0].name
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/AWSGSDatabaseFullPolicy"
}

resource "aws_iam_role_policy_attachment" "AWSGSLogFullPolicy" {
  count = var.enable_crossplane ? 1 : 0

  role       = aws_iam_role.crossplane[0].name
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/AWSGSLogFullPolicy"
}
resource "aws_iam_role_policy_attachment" "AWSGSNetworkFullPolicy" {
  count = var.enable_crossplane ? 1 : 0

  role       = aws_iam_role.crossplane[0].name
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/AWSGSNetworkFullPolicy"
}

resource "aws_iam_role_policy_attachment" "AWSGSStorageFullPolicy" {
  count = var.enable_crossplane ? 1 : 0

  role       = aws_iam_role.crossplane[0].name
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/AWSGSNetworkFullPolicy"
}

resource "aws_iam_policy" "CrossplaneControllerPolicy" {
  count = var.enable_crossplane ? 1 : 0

  name        = "AWSGSCrossplanePolicy"
  path        = "/"
  policy      = templatefile("${path.module}/policys/crossplane_policy.json", {})
}

resource "aws_iam_role_policy_attachment" "CrossplaneControllerPolicy" {
  count = var.enable_crossplane ? 1 : 0

  role       = aws_iam_role.crossplane[0].name
  policy_arn = aws_iam_policy.CrossplaneControllerPolicy.arn
}
