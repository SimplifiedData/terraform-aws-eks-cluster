variable "tags" { type = any }
variable "aws_account_name" { type = string }
variable "environment" { type = string }
variable "name_service" {
  type    = string
  default = null
}
variable "addons_config_password" {
  type = any
  default = {
    grafana = {}
    argocd  = {}
    # argowf = {}
  }
}
#********************************************************************************#
#                      *-- Variable for resource Network --*                     #
#********************************************************************************#
variable "vpc_id" {
  type = string
}
variable "certificate" {
  type    = string
  default = ""
}
#********************************************************************************#
#                       *-- Variable for resource EKS --*                        #
#********************************************************************************#
variable "cluster_name" {
  type = string
}
variable "cluster_version" {
  type    = number
  default = null
}
variable "fargate" {
  type    = any
  default = {}
}
#********************************************************************************#
#                      *-- Variable for resource AddOn --*                       #
#********************************************************************************#
variable "karpenter" {
  type = map(any)
  default = {
    name       = "karpenter"
    repository = "oci://public.ecr.aws/karpenter"
  }
}
variable "metrics" {
  type = map(any)
  default = {
    name       = "metrics-server"
    repository = "https://kubernetes-sigs.github.io/metrics-server/"
    namespace  = "kube-system"
  }
}
variable "argcd_ingress_name" {
  type    = string
  default = null
}
variable "grafana_ingress_name" {
  type    = string
  default = null
}
variable "argowf_ingress_name" {
  type    = string
  default = null
}
variable "argorollouts_ingress_name" {
  type    = string
  default = null
}
variable "enable_eksaddons" {
  type    = bool
  default = false
}

variable "kube_prometheus_stack" {
  type = any
  default = {
    namespace = "kube-prometheus-stack"
  }
}
variable "enable_prometheus_stack" {
  type    = bool
  default = false
}
variable "enable_grafana_ingress" {
  type    = bool
  default = false
}
variable "config_prometheus_stack" {
  type    = any
  default = []
}

variable "enable_argocd" {
  type    = bool
  default = false
}
variable "config_argocd" {
  type    = any
  default = []
}
variable "enable_argoworkflow" {
  type    = bool
  default = false
}
variable "config_argo_workflow" {
  type    = any
  default = []
}
variable "enable_argoevent" {
  type    = bool
  default = false
}
variable "config_argo_event" {
  type    = any
  default = []
}
variable "enable_argorollouts" {
  type    = bool
  default = false
}
variable "enable_argo_rollouts_dashboard" {
  type    = bool
  default = false
}
variable "config_argo_rollouts" {
  type    = any
  default = []
}
variable "enable_manifest_karpenter" {
  type    = bool
  default = false
}
variable "enable_manifest_karpenter_crds" {
  type    = bool
  default = false
}
variable "enable_crossplane" {
  type    = bool
  default = false
}
variable "crossplane" {
  type    = map(any)
  default = {}
}
variable "enable_load_balancer_controller" {
  type    = bool
  default = false
}
variable "enable_metrics_server" {
  type    = bool
  default = false
}
variable "enable_kube_prometheus_stack" {
  type    = bool
  default = false
}
variable "enable_argo_workflows" {
  type    = bool
  default = false
}
variable "enable_argo_events" {
  type    = bool
  default = false
}
variable "enable_argo_rollouts" {
  type    = bool
  default = false
}
variable "condition_values" {
  type    = any
  default = []
}
variable "aws_load_balancer_controller" {
  description = "AWS Load Balancer Controller add-on configuration values"
  type        = any
  default     = {}
}

variable "enable_alb_controller" {
  default = false
}

variable "argocd_version" {
  default = ""
}
variable "aws_lb_controller_version" {
  default = ""
}
variable "metrics_server_version" {
  default = ""
}
variable "kube_prometheus_stack_version" {
  default = ""
}
variable "argo_workflows_version" {
  default = ""
}
variable "argo_events_version" {
  default = ""
}
variable "argo_rollouts_version" {
  default = ""
}

variable "enable_node_group" {
  default = false
}
variable "manage_node_group" {
  type    = any
  default = {}
}
variable "aws_auth_fargate_profile_pod_execution_role_arns" {
  description = "List of Fargate profile pod execution role ARNs to add to the aws-auth configmap"
  type        = list(string)
  default     = []
}
