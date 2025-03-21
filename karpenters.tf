locals {
  category = var.environment == "production" ? "c,m" : "c,m,t"
  cpu      = var.environment == "production" ? "'4','8','16','32'" : "'4','8','16'"
  size     = var.environment == "production" ? "medium,large,xlarge,2xlarge,4xlarge" : "medium,large,xlarge"
}

##==================================================================
## KARPENTER Provision Node use VERSION 1.1.x
##==================================================================
resource "kubectl_manifest" "default_provisioner" {
  count     = var.enable_manifest_karpenter ? 1 : 0
  yaml_body = <<YAML
apiVersion: karpenter.sh/v1
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
      expireAfter: 720h
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
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
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 300s
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
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2023
  amiSelectorTerms:
  - alias: al2023@latest
  associatePublicIPAddress: false
  instanceProfile: "${module.eks_blueprints_addons.karpenter.node_instance_profile_name}"
  metadataOptions:
    httpEndpoint: enabled
    httpProtocolIPv6: disabled
    # httpPutResponseHopLimit: 2
    httpTokens: required
  subnetSelectorTerms:
    - tags:
        Name: '*-nonexpose-*'
    # - id: "%{~for i, v in data.aws_subnets.nonexpose.ids~}${v}%{if i < length(data.aws_subnets.nonexpose.ids) - 1}, %{endif}%{~endfor~}"
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
  tags:
    Name: kube_system_ng-by-karpenter_${module.eks.cluster_name}
    Environment: ${var.environment}
    Owner: ${var.tags["Owner"]}
    Service: ${var.tags["Service"]}
    System: ${var.tags["System"]}
    Createby: karpenter
    map-migrated: ${var.tags["map-migrated"]}
    app.kubernetes.io/created-by: karpenter
    karpenter.sh/discovery: ${module.eks.cluster_name}
YAML
  depends_on = [
    module.eks.cluster,
    module.eks_blueprints_addons.karpenter,
  ]
}