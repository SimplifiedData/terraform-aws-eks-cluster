locals {
  env           = var.environment != "dev" ? "" : "-${var.environment}"
  name          = "${var.tag_service}-${var.tag_system}-${var.name_service}"

  tags = {
    Service      = var.tag_service
    System       = var.tag_system
    Owner        = var.tag_owner
    Project      = var.tag_project
    Environment  = var.environment
    Manageby     = "terraform"
    map-migrated = var.map-migrated
    Createby     = var.createby
    ## Other.
  }
}

data "aws_acm_certificate" "rsa" {
  domain    = "*.7-11.io"
  statuses  = ["ISSUED"]
  key_types = ["RSA_2048"]
}
data "aws_caller_identity" "current" {}

module "eks" {
  source = "../../"

  cluster_name     = "${local.name}-3az-eks"
  name_service     = var.name_service

  aws_account_name = "gs-sds-sss-dev"

  vpc_id           = var.vpc_id
  environment      = var.environment
  certificate      = data.aws_acm_certificate.rsa.arn
  condition_values = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AWSGSDevRole"]

  enable_node_group = true
  manage_node_group = {
    karpenter = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["m5.large"]

      min_size     = 2
      max_size     = 3
      desired_size = 2

      taints = {
        addons = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        },
      }
    }
  }

  ## Note.!!!
  ## !!! These addons other Enable after Create Cluster done !!!.
  enable_manifest_karpenter = true
  enable_eksaddons          = true

  # enable_load_balancer_controller = true
  # aws_lb_controller_version = "1.8.0"
  # enable_metrics_server           = true # Migrate deploy at argocd
  # enable_kube_prometheus_stack    = true # Migrate deploy at argocd

  ## Argo Family ----------
  # enable_argocd  = true
  # argocd_version = "7.2.1"
  # config_argocd = [templatefile("${path.module}/helm/argocd.yaml", {
  #   cognito_sso_id     = module.ArgoCD_SSO_SecretManager_ID.stdout
  #   cognito_sso_secret = module.ArgoCD_SSO_SecretManager_PW.stdout
  # })]
  # enable_argo_workflows = true
  # argo_workflows_version = "0.41.8"
  # config_argo_workflow = [templatefile("${path.module}/helm/argowf.yaml", {
  #   cognito_sso_id     = module.ArgoWF_SSO_SecretManager_ID.stdout
  #   cognito_sso_secret = module.ArgoWF_SSO_SecretManager_PW.stdout
  # })]

  ### Migrate deploy at argocd ###-----------
  # enable_argo_events    = true
  # argo_events_version   = "2.4.2"
  # config_argo_event     = []
  # enable_argo_rollouts  = true
  # argo_rollouts_version = "2.34.2"
  # config_argo_rollouts  = []
  ### Migrate deploy at argocd ###-----------
  ## Crossplane ----------
  # enable_crossplane = true # SET IRSA for use on EKS.

  # fargate = {
  #   karpenter = {
  #     selectors = [
  #       { namespace = "karpenter" }
  #     ]
  #   }
  # }

  tags = local.tags
}
