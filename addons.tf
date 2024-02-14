module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.9.2"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn
  # We want to wait for the Fargate profiles to be deployed first
  create_delay_dependencies = [for prof in module.eks.fargate_profiles : prof.fargate_profile_arn]

  # [ Karpenter ] ============================================================================##
  enable_karpenter = true
  # karpenter_enable_instance_profile_creation = false
  karpenter = {
    chart_version       = local.karpenter["version"]
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
    values = [templatefile("${path.module}/helm/karpenters/values.yaml", {
      replicas = var.environment == "production" ? 3 : 2
      requests_cpu = var.environment == "production" ? "1000m" : "500m"
    })]
    role_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }
  karpenter_enable_spot_termination = true
  karpenter_node = {
    # create_instance_profile = true
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }
  ##==========================================================================================##
}

module "eks_blueprints_addons_system" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.9.2"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn
  # We want to wait for the Fargate profiles to be deployed first
  # create_delay_dependencies = [for prof in module.eks.fargate_profiles : prof.fargate_profile_arn]
  # [ Addons For System] =====================================================================##
  eks_addons = var.enable_eksaddons ? {
    coredns = {
      configuration_values = jsonencode({
        # computeType = "Fargate"
        nodeSelector = {
          system      = var.tags["System"]
          manage-team = "devops"
          namespace   = "kube-system"
        }
        tolerations = [
          {
            key      = "devopsMangement"
            operator = "Exists"
            effect   = "NoSchedule"
          },
        ]
        resources = {
          limits = {
            cpu = "0.25"
            # We are targeting the smallest Task size of 512Mb, so we subtract 256Mb from the request/limit to ensure we can fit within that task
            memory = "256M"
          }
          requests = {
            cpu = "0.25"
            # We are targeting the smallest Task size of 512Mb, so we subtract 256Mb from the request/limit to ensure we can fit within that task
            memory = "256M"
          }
        }
      })
    }
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
      configuration_values = jsonencode({
        controller = {
          nodeSelector = {
            system      = var.tags["System"]
            manage-team = "devops"
            namespace   = "kube-system"
          }
          tolerations = [
            {
              key      = "devopsMangement"
              operator = "Exists"
              effect   = "NoSchedule"
            },
          ]
        }
      })
    }
    vpc-cni = { most_recent = true }
    kube-proxy = {}
  } : {}
  ##==========================================================================================##
  # [--- ARGO CD ---] ========================================================================##
  enable_argocd = var.enable_argocd
  argocd = {
    chart_version = local.argocd["version"]
    set_sensitive = [{
      name  = "configs.secret.argocdServerAdminPassword"
      value = try(bcrypt(random_password.default["argocd"].result), "")
    }]
    set = [{
      name  = "redis-ha.haproxy.image.repository"
      value = "public.ecr.aws/docker/library/haproxy"
      },
      {
        name  = "redis-ha.image.repository"
        value = "public.ecr.aws/docker/library/redis"
    }]
    values = setunion(var.config_argocd, [templatefile("${path.module}/helm/argocd/values.yaml", {
      global_log_format      = "json"
      tags_system            = var.tags["System"]
      ingress_enabled        = true
      ingress_grpc_enabled   = true
      server_metrics_enabled = true
      ingress_name           = local.argocd_ingress
      ingress_certs_arn      = var.certificate
      ingress_ssl_policy     = local.ingress_ssl_policy
      ingress_subnets        = join(",", data.aws_subnets.app.ids)
      ingress_tags = join(",", formatlist(
        "%s=%s", keys(merge(tomap(
          { Name = local.argocd_ingress }), var.tags)), values(merge(tomap({ Name = local.argocd_ingress }
        ), var.tags))
      ))
    })])
  }
  # [--]
  enable_cluster_proportional_autoscaler = var.enable_eksaddons
  cluster_proportional_autoscaler = {
    chart_version = local.cluster_proportional_autoscaler["version"]
    values        = [templatefile("${path.module}/helm/cluster_proportional_autoscaler/values.yaml", {})]
  }
  ##==========================================================================================##
  # enable_aws_load_balancer_controller = var.enable_eksaddons
  # aws_load_balancer_controller = {
  #   chart_version = local.aws_load_balancer_controller["version"]
  #   values = [templatefile("${path.module}/helm/load_balancer_controller/values.yaml", {
  #     vpc_id = var.vpc_id
  #   })]
  # }
  depends_on = [kubectl_manifest.system_nodetemplate, kubectl_manifest.system_provisioner]
}


