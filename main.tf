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
  version = "20.11.1"

  cluster_name                   = var.cluster_name
  cluster_version                = try(local.cluster_version, var.cluster_version)

  # Terraform identity admin access to cluster wich will allow deploying resources (Karpenter) into the cluster.
  # enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access           = true

  cluster_addons = {
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
    kube-proxy = { most_recent = true }
  }

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
