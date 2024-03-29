data "aws_availability_zones" "available" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

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
  account_dev = [
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
  ]
  account_prd = [
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AWSGSDevOpsRole"
      username = "devops-role"
      groups   = ["system:masters"]
    }
  ]

  cluster_version    = 1.29
  ingress_ssl_policy = "ELBSecurityPolicy-TLS13-1-3-2021-06"

  #============================================
  ## ADDON Version
  #============================================
  karpenter = {
    version = "0.35.2"
  }
  argocd = {
    version = "6.7.3"
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

#============================================
# Get Subnet ID and VPC
#============================================
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}
data "aws_subnets" "app" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  tags = {
    Name = "*app*"
  }
}
data "aws_subnets" "nonexpose" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  tags = {
    Name = "*nonexpose*"
  }
}

#============================================
## Get Authen Token ECR public              #
#============================================
provider "aws" {
  region = "us-east-1"
  alias  = "virginia"
}
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}
resource "random_string" "default" {
  length  = 4
  special = false
  upper   = false
}

#============================================
# Module EKS Cluster                        #
#============================================
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name                   = var.cluster_name
  cluster_version                = try(local.cluster_version, var.cluster_version)
  cluster_endpoint_public_access = true

  vpc_id     = var.vpc_id
  subnet_ids = data.aws_subnets.nonexpose.ids

  # Fargate profiles use the cluster primary security group so these are not utilized
  create_cluster_security_group            = false
  create_node_security_group               = false
  # enable_cluster_creator_admin_permissions = true
  manage_aws_auth_configmap = true
  aws_auth_roles = setunion(var.environment == "production" ? local.account_prd : local.account_dev,
    [
      {
        rolearn  = module.eks_blueprints_addons.karpenter.node_iam_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes",
        ]
      }
    ]
  )

  iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
  cluster_enabled_log_types              = ["audit", "api"]
  cloudwatch_log_group_retention_in_days = 14

  fargate_profiles = merge(var.fargate, {
    karpenter = {
      selectors = [
        { namespace = "karpenter" }
      ]
    }
  })

  tags = merge(var.tags, {
    Name                     = var.cluster_name
    "karpenter.sh/discovery" = var.cluster_name
  })
}

#============================================
# Tag VPC, Tested on awscli 2.9.8           #
#============================================
resource "null_resource" "vpc_lz" {
  lifecycle {
    create_before_destroy = true
  }

  triggers = {
    cluster_name = var.cluster_name
    vpc          = var.vpc_id
  }

  provisioner "local-exec" {
    command = <<EOF
    aws ec2 create-tags --resources ${self.triggers.vpc} --tags Key=kubernetes.io/cluster/${self.triggers.cluster_name},Value=shared Key=karpenter.sh/discovery,Value=${self.triggers.cluster_name}
    EOF
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
    aws ec2 delete-tags --resources ${self.triggers.vpc} --tags Key=kubernetes.io/cluster/${self.triggers.cluster_name},Value=shared Key=karpenter.sh/discovery,Value=${self.triggers.cluster_name}
    EOF
  }
}

# Tag Subnets, Tested on awscli 2.9.8
resource "null_resource" "subnet_lz_apps" {
  lifecycle {
    create_before_destroy = true
  }

  triggers = {
    cluster_name = var.cluster_name
    subnets      = join(" ", data.aws_subnets.app.ids)
  }

  provisioner "local-exec" {
    command = <<EOF
    aws ec2 create-tags --resources ${self.triggers.subnets} --tags Key=kubernetes.io/role/internal-elb,Value=1 Key=kubernetes.io/cluster/${self.triggers.cluster_name},Value=shared Key=karpenter.sh/discovery,Value=${self.triggers.cluster_name}
    EOF
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
    aws ec2 delete-tags --resources ${self.triggers.subnets} --tags Key=kubernetes.io/role/internal-elb,Value=1 Key=kubernetes.io/cluster/${self.triggers.cluster_name},Value=shared Key=karpenter.sh/discovery,Value=${self.triggers.cluster_name}
    EOF
  }
}

resource "null_resource" "subnet_lz_nonexpose" {
  lifecycle {
    create_before_destroy = true
  }

  triggers = {
    cluster_name = var.cluster_name
    subnets      = join(" ", data.aws_subnets.nonexpose.ids)
  }

  provisioner "local-exec" {
    command = <<EOF
    aws ec2 create-tags --resources ${self.triggers.subnets} --tags Key=kubernetes.io/role/internal-elb,Value=1 Key=kubernetes.io/cluster/${self.triggers.cluster_name},Value=shared Key=karpenter.sh/discovery,Value=${self.triggers.cluster_name}
    EOF
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
    aws ec2 delete-tags --resources ${self.triggers.subnets} --tags Key=kubernetes.io/role/internal-elb,Value=1 Key=kubernetes.io/cluster/${self.triggers.cluster_name},Value=shared Key=karpenter.sh/discovery,Value=${self.triggers.cluster_name}
    EOF
  }
}
