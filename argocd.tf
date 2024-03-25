# data "aws_eks_cluster" "cluster" {
#   name = module.eks.cluster_name
# }
# resource "argocd_cluster" "eks" {
#   server     = format("https://%s", data.aws_eks_cluster.cluster.endpoint)
#   name       = "eks"

#   config {
#     aws_auth_config {
#       cluster_name = module.eks.cluster_name
#       role_arn     = "arn:aws:iam::<123456789012>:role/<role-name>"
#     }
#     tls_client_config {
#       ca_data = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
#     }
#   }
# }
