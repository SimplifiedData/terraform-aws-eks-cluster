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
  version = "20.17.2"

  cluster_name                   = var.cluster_name
  cluster_version                = try(var.cluster_version, local.cluster_version)

  # Terraform identity admin access to cluster wich will allow deploying resources (Karpenter) into the cluster.
  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access           = true
  authentication_mode = "API_AND_CONFIG_MAP"

  vpc_id     = var.vpc_id
  subnet_ids = data.aws_subnets.nonexpose.ids
  control_plane_subnet_ids = data.aws_subnets.nonexpose.ids
  # Fargate profiles use the cluster primary security group so these are not utilized
  create_cluster_security_group = var.enable_node_group == true ? true : false
  create_node_security_group    = var.enable_node_group == true ? true : false

  eks_managed_node_groups = var.enable_node_group ? var.manage_node_group : {}

  iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
  cluster_enabled_log_types              = ["audit", "api"]
  cloudwatch_log_group_retention_in_days = 14

  fargate_profiles = merge(var.fargate, {
    # karpenter = {
    #   selectors = [
    #     { namespace = "karpenter" }
    #   ]
    # }
  })

  tags = merge(var.tags, {
    Name                     = var.cluster_name
    "karpenter.sh/discovery" = var.cluster_name
  })
}

locals {
  fargate_profile_pod_execution_role_arns = distinct(
    compact(
      concat(
        [for group in module.eks.fargate_profiles : group.fargate_profile_pod_execution_role_arn],
        var.aws_auth_fargate_profile_pod_execution_role_arns,
      )
    )
  )
}


module "eks_aws_auth" {
  source  = "terraform-aws-modules/eks/aws//modules/aws-auth"
  version = "20.17.2"

  manage_aws_auth_configmap = true
  aws_auth_roles = setunion(var.environment == "production" || var.environment == "prod" ? local.account_prd : local.account_dev,
    [
      {
        rolearn  = module.eks_blueprints_addons.karpenter.node_iam_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes",
        ]
      }
    ],
    # [
    #   for role_arn in local.fargate_profile_pod_execution_role_arns : {
    #     rolearn  = role_arn
    #     username = "system:node:{{SessionName}}"
    #     groups = [
    #       "system:bootstrappers",
    #       "system:nodes",
    #       "system:node-proxier",
    #     ]
    #   }
    # ]
  )
}


module "eks_aws_auth" {
  source  = "terraform-aws-modules/eks/aws//modules/aws-auth"
  version = "20.11.1"

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

#==================#
# Karpenter IRSA
#==================#
data "http" "nodepools" {
  # url = "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v0.32.7/pkg/apis/crds/karpenter.sh_nodepools.yaml"
  url = "https://raw.githubusercontent.com/aws/karpenter/v0.37.0/pkg/apis/crds/karpenter.sh_nodepools.yaml"
  request_headers = {
    Accept = "text/plain"
  }
}
resource "kubectl_manifest" "nodepools" {
  yaml_body = data.http.nodepools.body
}

data "http" "nodeclaims" {
  # url = "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v0.32.7/pkg/apis/crds/karpenter.sh_nodeclaims.yaml"
  url = "https://raw.githubusercontent.com/aws/karpenter/v0.37.0/pkg/apis/crds/karpenter.sh_nodeclaims.yaml"
  request_headers = {
    Accept = "text/plain"
  }
}
resource "kubectl_manifest" "nodeclaims" {
  yaml_body = data.http.nodeclaims.body
}

data "http" "ec2nodeclasses" {
  # url = "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v0.32.7/pkg/apis/crds/karpenter.k8s.aws_ec2nodeclasses.yaml"
  url = "https://raw.githubusercontent.com/aws/karpenter/v0.37.0/pkg/apis/crds/karpenter.k8s.aws_ec2nodeclasses.yaml"
  request_headers = {
    Accept = "text/plain"
  }
}
resource "kubectl_manifest" "ec2nodeclasses" {
  yaml_body = data.http.ec2nodeclasses.body
}
