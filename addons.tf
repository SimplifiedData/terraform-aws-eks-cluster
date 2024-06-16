module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.16.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn
  # We want to wait for the Fargate profiles to be deployed first
  create_delay_dependencies = [for prof in module.eks.fargate_profiles : prof.fargate_profile_arn]

  # [ Karpenter ] ============================================================================##
  enable_karpenter                           = true
  karpenter_enable_instance_profile_creation = false
  karpenter = {
    chart_version = local.karpenter["version"]
    # repository          = "oci://public.ecr.aws/karpenter/karpenter-crd"
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
    values = [templatefile("${path.module}/k8s/helm/karpenters/values.yaml", {
      replicas        = var.environment == "production" ? 3 : 2
      requests_cpu    = var.environment == "production" ? "1000m" : "500m"
      requests_memory = var.environment == "production" ? "2Gi" : "1Gi"
    })]
  }
  karpenter_node = {
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }
  ##==========================================================================================##

  # IF Don't use deploy addons by argocd
  # [ LoadBalancer_Controller ] ==============================================================##
  enable_aws_load_balancer_controller = var.enable_load_balancer_controller
  aws_load_balancer_controller = {
    chart_version = try(var.aws_lb_controller_version, local.aws_load_balancer_controller["version"])
    values = [templatefile("${path.module}/k8s/helm/load_balancer_controller/values.yaml", {
      vpc_id = var.vpc_id
    })]
  }
  ##==========================================================================================##
  # [ Metrics_server ]
  enable_metrics_server = var.enable_metrics_server
  metrics_server = {
    chart_version = try(var.metrics_server_version, local.metrics-server["version"])
    values        = [templatefile("${path.module}/k8s/helm/metrics_server/values.yaml", {})]
  }
  ##==========================================================================================##
  # [ Prometheus and Grafana ] ===============================================================##
  enable_kube_prometheus_stack = var.enable_kube_prometheus_stack
  kube_prometheus_stack = {
    chart_version = try(var.kube_prometheus_stack_version, local.kube_prometheus_stack["version"])
    values = setunion(var.config_prometheus_stack, [templatefile("${path.module}/k8s/helm/kube_prometheus_stack/values.yaml", {
      ingress_enabled    = var.enable_grafana_ingress
      tags_system            = var.tags["System"]
      grafana_password   = random_password.grafana.result[*]
      ingress_certs_arn  = var.certificate
      ingress_name       = local.grafana_ingress
      ingress_ssl_policy = local.ingress_ssl_policy
      ingress_subnets    = join(",", data.aws_subnets.app.ids)
      ingress_tags = join(",", formatlist(
        "%s=%s", keys(merge(tomap(
          { Name = local.grafana_ingress }), var.tags)), values(merge(tomap({ Name = local.grafana_ingress }
        ), var.tags))
      ))
    })])
  }
  ##==========================================================================================##
  # [--- ARGO Workflows ---] =================================================================##
  enable_argo_workflows = var.enable_argo_workflows
  argo_workflows = {
    chart_version = try(var.argo_workflows_version, local.argo_workflows["version"])
    values = setunion(var.config_argo_workflow, [templatefile("${path.module}/k8s/helm/argo_workflow/values.yaml", {
      ingress_enabled    = true
      ingress_name       = local.argowf_ingress
      ingress_certs_arn  = var.certificate
      ingress_ssl_policy = local.ingress_ssl_policy
      ingress_subnets    = join(",", data.aws_subnets.app.ids)
      ingress_tags = join(",", formatlist(
        "%s=%s", keys(merge(tomap(
          { Name = local.argowf_ingress }), var.tags)), values(merge(tomap({ Name = local.argowf_ingress }
        ), var.tags))
      ))
    })])
  }
  ##==========================================================================================##
  # [--- ARGO Event ---] =====================================================================##
  enable_argo_events = var.enable_argo_events
  argo_events = {
    chart_version = try(var.argo_events_version, local.argo_event["version"])
    values        = setunion(var.config_argo_event, [templatefile("${path.module}/k8s/helm/argoevent/values.yaml", {})])
  }
  ##==========================================================================================##
  # [--- ARGO rollouts ---] ==================================================================##
  enable_argo_rollouts = var.enable_argo_rollouts
  argo_rollouts = {
    chart_version = try(var.argo_rollouts_version, local.argo_rollout["version"])
    values = setunion(var.config_argo_rollouts, [templatefile("${path.module}/k8s/helm/argorollouts/values.yaml", {
      enable_dashboard   = true #var.enable_argo_rollouts_dashboard
      ingress_enabled    = true #var.enable_argo_rollouts_dashboard
      ingress_name       = local.argorollouts_ingress
      ingress_certs_arn  = var.certificate
      ingress_ssl_policy = local.ingress_ssl_policy
      ingress_subnets    = join(",", data.aws_subnets.app.ids)
      ingress_tags = join(",", formatlist(
        "%s=%s", keys(merge(tomap(
          { Name = local.argorollouts_ingress }), var.tags)), values(merge(tomap({ Name = local.argorollouts_ingress }
        ), var.tags))
      ))
    })])
  }
  ##==========================================================================================##

}

module "eks_blueprints_addons_system" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.16.0"

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
          "kubernetes.io/arch" = "arm64"
          system               = var.tags["System"]
          manage-team          = "devops"
          namespace            = "kube-system"
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
            "kubernetes.io/arch" = "arm64"
            system               = var.tags["System"]
            manage-team          = "devops"
            namespace            = "kube-system"
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
    vpc-cni    = { most_recent = true }
    kube-proxy = {}
  } : {}
  ##==========================================================================================##
  # [--- ARGO CD ---] ========================================================================##
  enable_argocd = var.enable_argocd

  argocd = {
    chart_version = try(var.argocd_version, local.argocd["version"])
    set_sensitive = [{
      name  = "configs.secret.argocdServerAdminPassword"
      value = bcrypt(random_password.argocd.result[*])
    }]
    set = [{
      name  = "redis-ha.haproxy.image.repository"
      value = "public.ecr.aws/docker/library/haproxy"
      },
      {
        name  = "redis-ha.image.repository"
        value = "public.ecr.aws/docker/library/redis"
    }]
    values = setunion(var.config_argocd, [templatefile("${path.module}/k8s/helm/argocd/values.yaml", {
      global_log_format      = "json"
      tags_system            = var.tags["System"]
      ingress_enabled        = var.certificate != null ? true : false
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
    values        = [templatefile("${path.module}/k8s/helm/cluster_proportional_autoscaler/values.yaml", {})]
  }
  ##==========================================================================================##

  depends_on = [kubectl_manifest.default_provisioner, kubectl_manifest.default_nodetemplate]
}

module "ebs_csi_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name             = "${module.eks.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}
