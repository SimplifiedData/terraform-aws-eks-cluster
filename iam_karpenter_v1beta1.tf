resource "aws_iam_policy" "karpenter" {
  name        = "KarpenterControllerPolicy-${module.eks.cluster_name}-v1beta1"
  path        = "/"
  description = "KarpenterControllerPolicy-${module.eks.cluster_name}-v1beta1"
  policy = templatefile("${path.module}/policys/karpenter_policy.json", {
    accunt_id    = data.aws_caller_identity.current.account_id
    cluster_name = module.eks.cluster_name
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_additional" {
  role       = replace(module.eks_blueprints_addons.gitops_metadata.karpenter_iam_role_arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/", "")
  policy_arn = aws_iam_policy.karpenter.arn
}
