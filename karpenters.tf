locals {
  category = var.environment == "production" ? "c,m" : "c,m,t"
  cpu      = var.environment == "production" ? "'4','8','16','32'" : "'4','8','16'"
  size     = var.environment == "production" ? "medium,large,xlarge,2xlarge,4xlarge" : "medium,large,xlarge"
}
##==================================================================
## KARPENTER Update CRDs
##==================================================================
# Kube Apply CRDs
data "http" "provisioners" {
  url = "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v0.32.7/pkg/apis/crds/karpenter.sh_provisioners.yaml"
  request_headers = {
    Accept = "text/plain"
  }
}
resource "kubectl_manifest" "provisioners" {
  count     = var.enable_manifest_karpenter ? 1 : 0
  yaml_body = data.http.provisioners.body

  depends_on = [
    module.eks.cluster,
    module.eks_blueprints_addons.karpenter,
  ]
}

data "http" "machines" {
  url = "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v0.32.7/pkg/apis/crds/karpenter.sh_machines.yaml"
  request_headers = {
    Accept = "text/plain"
  }
}
resource "kubectl_manifest" "machines" {
  count     = var.enable_manifest_karpenter ? 1 : 0
  yaml_body = data.http.machines.body

  depends_on = [
    module.eks.cluster,
    module.eks_blueprints_addons.karpenter,
  ]
}

data "http" "awsnodetemplates" {
  url = "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v0.32.7/pkg/apis/crds/karpenter.k8s.aws_awsnodetemplates.yaml"
  request_headers = {
    Accept = "text/plain"
  }
}
resource "kubectl_manifest" "awsnodetemplates" {
  count     = var.enable_manifest_karpenter ? 1 : 0
  yaml_body = data.http.awsnodetemplates.body

  depends_on = [
    module.eks.cluster,
    module.eks_blueprints_addons.karpenter,
  ]
}

data "http" "nodepools" {
  url = "https://raw.githubusercontent.com/aws/karpenter/v0.35.1/pkg/apis/crds/karpenter.sh_nodepools.yaml"
  request_headers = {
    Accept = "text/plain"
  }
}
resource "kubectl_manifest" "nodepools" {
  count     = var.enable_manifest_karpenter ? 1 : 0
  yaml_body = data.http.nodepools.body

  depends_on = [
    module.eks.cluster,
    module.eks_blueprints_addons.karpenter,
  ]
}

data "http" "nodeclaims" {
  url = "https://raw.githubusercontent.com/aws/karpenter/v0.35.1/pkg/apis/crds/karpenter.sh_nodeclaims.yaml"
  request_headers = {
    Accept = "text/plain"
  }
}
resource "kubectl_manifest" "nodeclaims" {
  count     = var.enable_manifest_karpenter ? 1 : 0
  yaml_body = data.http.nodeclaims.body

  depends_on = [
    module.eks.cluster,
    module.eks_blueprints_addons.karpenter,
  ]
}

data "http" "ec2nodeclasses" {
  url = "https://raw.githubusercontent.com/aws/karpenter/v0.35.1/pkg/apis/crds/karpenter.k8s.aws_ec2nodeclasses.yaml"
  request_headers = {
    Accept = "text/plain"
  }
}
resource "kubectl_manifest" "ec2nodeclasses" {
  count     = var.enable_manifest_karpenter ? 1 : 0
  yaml_body = data.http.ec2nodeclasses.body

  depends_on = [
    module.eks.cluster,
    module.eks_blueprints_addons.karpenter,
  ]
}

##==================================================================
## KARPENTER Provision Node use VERSION 0.35.x
##==================================================================
resource "kubectl_manifest" "default_provisioner" {
  count     = var.enable_manifest_karpenter ? 1 : 0
  yaml_body = <<YAML
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
spec:
  template:
    metadata:
      labels:
        system: "${var.tags["System"]}"
        manage-team: devops
        namespace: kube-system
      annotations:
        system: "${var.tags["System"]}"
        manage-team: devops
        namespace: kube-system
    spec:
      nodeClassRef:
        name: default
      taints:
        - key: "devopsMangement"
          value: "true"
          effect: "NoSchedule"
      requirements:
        - key: "karpenter.k8s.aws/instance-category"
          operator: In
          values: [${local.category}]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: In
          values: [${local.cpu}]
        - key: "karpenter.k8s.aws/instance-size"
          operator: In
          values: [${local.size}]
        - key: "karpenter.k8s.aws/instance-hypervisor"
          operator: In
          values: ["nitro"]
        - key: "kubernetes.io/arch"
          operator: In
          values: ["arm64", "amd64"]
        - key: "karpenter.sh/capacity-type" # If not included, the webhook for the AWS cloud provider will default to on-demand
          operator: In
          values: ["on-demand"]
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 300s
    expireAfter: 720h
  limits:
    cpu: "1000"
    memory: 1000Gi
YAML
  depends_on = [
    module.eks.cluster,
    module.eks_blueprints_addons.karpenter,
    kubectl_manifest.default_nodetemplate
  ]
}

resource "kubectl_manifest" "default_nodetemplate" {
  count     = var.enable_manifest_karpenter ? 1 : 0
  yaml_body = <<YAML
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2
  associatePublicIPAddress: false
  subnetSelectorTerms:
    - tags:
        Name: "*nonexpose*"
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
  instanceProfile: "${module.eks_blueprints_addons.karpenter.node_instance_profile_name}"
  tags:
    Name: "kube_system_ng-by-karpenter_${module.eks.cluster_name}"
    Environment: "${var.environment}"
    Owner: "${var.tags["Owner"]}"
    Service: "${var.tags["Service"]}"
    System: "${var.tags["System"]}"
    Createby: "karpenter"
    map-migrated: "${var.tags["map-migrated"]}"
    app.kubernetes.io/created-by: "karpenter"
    karpenter.sh/discovery: "${module.eks.cluster_name}"
YAML

  depends_on = [
    module.eks.cluster,
    module.eks_blueprints_addons.karpenter,
    kubectl_manifest.provisioners,
    kubectl_manifest.machines,
    kubectl_manifest.awsnodetemplates,
    kubectl_manifest.nodepools,
    kubectl_manifest.nodeclaims,
    kubectl_manifest.ec2nodeclasses
  ]
}
