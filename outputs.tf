output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks.cluster_arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_id" {
  description = "The ID of the EKS cluster. Note: currently a value is returned only for local EKS clusters created on Outposts"
  value       = module.eks.cluster_id
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_platform_version" {
  description = "Platform version for the cluster"
  value       = module.eks.cluster_platform_version
}

output "cluster_status" {
  description = "Status of the EKS cluster. One of `CREATING`, `ACTIVE`, `DELETING`, `FAILED`"
  value       = module.eks.cluster_status
}

output "cluster_primary_security_group_id" {
  description = "Cluster security group that was created by Amazon EKS for the cluster. Managed node groups use this security group for control-plane-to-data-plane communication. Referred to as 'Cluster security group' in the EKS console"
  value       = module.eks.cluster_primary_security_group_id
}

################################################################################
# Security Group
################################################################################

output "cluster_security_group_arn" {
  description = "Amazon Resource Name (ARN) of the cluster security group"
  value       = module.eks.cluster_security_group_arn
}

output "cluster_security_group_id" {
  description = "ID of the cluster security group"
  value       = module.eks.cluster_security_group_id
}

################################################################################
# Node Security Group
################################################################################

output "node_security_group_arn" {
  description = "Amazon Resource Name (ARN) of the node shared security group"
  value       = module.eks.node_security_group_arn
}

output "node_security_group_id" {
  description = "ID of the node shared security group"
  value       = module.eks.node_security_group_id
}

################################################################################
# IRSA
################################################################################

output "oidc_provider" {
  description = "The OpenID Connect identity provider (issuer URL without leading `https://`)"
  value       = module.eks.oidc_provider
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if `enable_irsa = true`"
  value       = module.eks.oidc_provider_arn
}

output "cluster_tls_certificate_sha1_fingerprint" {
  description = "The SHA1 fingerprint of the public key of the cluster's certificate"
  value       = module.eks.cluster_tls_certificate_sha1_fingerprint
}

################################################################################
# IAM Role
################################################################################

output "cluster_iam_role_name" {
  description = "IAM role name of the EKS cluster"
  value       = module.eks.cluster_iam_role_name
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = module.eks.cluster_iam_role_arn
}

output "cluster_iam_role_unique_id" {
  description = "Stable and unique string identifying the IAM role"
  value       = module.eks.cluster_iam_role_unique_id
}

################################################################################
# EKS Addons
################################################################################

output "cluster_addons" {
  description = "Map of attribute maps for all EKS cluster addons enabled"
  value       = module.eks.cluster_addons
}

################################################################################
# EKS Identity Provider
################################################################################

output "cluster_identity_providers" {
  description = "Map of attribute maps for all EKS identity providers enabled"
  value       = module.eks.cluster_identity_providers
}

################################################################################
# CloudWatch Log Group
################################################################################

output "cloudwatch_log_group_name" {
  description = "Name of cloudwatch log group created"
  value       = module.eks.cloudwatch_log_group_name
}

output "cloudwatch_log_group_arn" {
  description = "Arn of cloudwatch log group created"
  value       = module.eks.cloudwatch_log_group_arn
}

################################################################################
# Fargate Profile
################################################################################
output "fargate_profiles" {
  description = "Map of attribute maps for all EKS Fargate Profiles created"
  value       = module.eks.fargate_profiles
}
################################################################################
# Additional - REMOVE 
################################################################################
# output "aws_auth_configmap_yaml" {
#   description = "Formatted yaml output for base aws-auth configmap containing roles used in cluster node groups/fargate profiles"
#   value       = module.eks.aws_auth_configmap_yaml
# }
################################################################################
# Node IAM Instance Profile
################################################################################
output "karpenter" {
  value = module.eks_blueprints_addons.karpenter
}
output "karpenter_node_instance_profile_name" {
  value = module.eks_blueprints_addons.karpenter.node_instance_profile_name
}
output "karpenter_node_role" {
  value = module.eks_blueprints_addons.karpenter.node_iam_role_arn
}

## Output Argo Family
output "argo_rollouts" {
  description = "Map of attributes of the Helm release created"
  value       = module.eks_blueprints_addons.argo_rollouts
}
output "argo_workflows" {
  description = "Map of attributes of the Helm release created"
  value       = module.eks_blueprints_addons.argo_workflows
}
output "argocd" {
  description = "Map of attributes of the Helm release created"
  value       = module.eks_blueprints_addons.argocd
}
output "argo_events" {
  description = "Map of attributes of the Helm release created"
  value       = module.eks_blueprints_addons.argo_events
}

## Output Prometheus Stack
output "kube_prometheus_stack" {
  description = "Map of attributes of the Helm release and IRSA created"
  value       = module.eks_blueprints_addons.kube_prometheus_stack
}

output "gitops_metadata_iam_role_arn" {
  value = module.eks_blueprints_addons.gitops_metadata.karpenter_iam_role_arn
}

output "gitops_metadata_service_account" {
  value = module.eks_blueprints_addons.gitops_metadata.karpenter_service_account
}

### Crossplane Role
output "crossplane_role" {
  value = try(aws_iam_role.crossplane[*].arn, null)
}

### IAM ROlE ALB Controller
output "albcontroller_role" {
  value = aws_iam_role.albrole.arn
}
