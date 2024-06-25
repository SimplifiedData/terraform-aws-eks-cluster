locals {
  name                  = var.cluster_name
  subnet_ids_non        = "%{for i, v in data.aws_subnets.nonexpose.ids}${v}%{if i < length(data.aws_subnets.nonexpose.ids) - 1}, %{endif}%{endfor}"
  addon_enable_password = var.enable_argocd || var.enable_grafana_ingress == true
  env                   = var.environment != "dev" ? "" : var.environment
  argocd_ingress        = var.argcd_ingress_name == null ? "k8s-argocd-${var.name_service}-${local.env}${random_string.default.result}" : var.argcd_ingress_name
  grafana_ingress       = var.grafana_ingress_name == null ? "k8s-grafana-${var.name_service}-${local.env}${random_string.default.result}" : var.grafana_ingress_name
  argowf_ingress        = var.argowf_ingress_name == null ? "k8s-argowf-${var.name_service}-${local.env}${random_string.default.result}" : var.argowf_ingress_name
  argorollouts_ingress  = var.argorollouts_ingress_name == null ? "k8s-argo-ro-${var.name_service}-${local.env}${random_string.default.result}" : var.argorollouts_ingress_name
  dns_suffix            = data.aws_partition.current.dns_suffix
  partition             = data.aws_partition.current.partition
  account_dev = setunion( var.enable_node_group ? [] : [], [
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AWSGSDevOpsRole"
      username = "devops-role"
      groups   = ["system:masters"]
    },
    # Map user in DevRole
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AWSGSDevRole"
      username = "dev-role"
      groups   = ["system:masters"]
    }
  ])
  account_prd = setunion( var.enable_node_group ? [] : [], [
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AWSGSDevOpsRole"
      username = "devops-role"
      groups   = ["system:masters"]
    }
  ])

  cluster_version    = 1.29
  ingress_ssl_policy = "ELBSecurityPolicy-TLS13-1-3-2021-06"

  #============================================
  ## ADDON Version
  #============================================
  karpenter = {
    version = "0.37.0"
  }
  argocd = {
    # Updated to use ArgoCD version greater than 2.11.0
    # ArgoCD security code: CVE-2024-31989
    version = "7.1.1"
  }
  # __________MOVE TO ArgoCD__________
  aws_load_balancer_controller = {
    version = "1.7.2"
  }
  cluster_proportional_autoscaler = {
    version = "1.1.0"
  }
  metrics-server = {
    version = "3.12.0"
  }
  kube_prometheus_stack = {
    version = "57.1.1"
  }
  argo_workflows = {
    version = "0.41.0"
  }
  argo_event = {
    version = "2.4.4"
  }
  argo_rollout = {
    version = "2.35.0"
  }
  crossplane = {
    version = "1.15.1-up.1"
  }
  #___________________________________
}
