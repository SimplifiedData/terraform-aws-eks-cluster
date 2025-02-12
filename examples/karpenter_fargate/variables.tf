#---------------#
# Resource TAGs #
#---------------#
variable "createby" {
  type        = string
  description = "Who has perform this operation, Please type your UserLan. (กรุณาพิมพ์ User Lan ของคุณ)"
}
variable "tag_owner" {
  type        = string
  description = "The resource owner id, example cpall or gosoft."
}
variable "tag_project" {
  type        = string
  description = "The project name."
}
variable "tag_service" {
  type        = string
  description = "The service code id, example sds, rpa or etc."
}
variable "tag_system" {
  type        = string
  description = "The system code id, example: sss, sms or etc."
}
variable "environment" {
  type        = string
  description = "The environment name, example: dev, production or etc."
}
variable "map-migrated" {
  type        = string
  description = "The map-migrated is discount code by environment."
  default     = ""
}

# [ Variable Cluster ]
variable "name_service" {
  type = string
}
variable "cluster_version" {
  type = number
}
variable "vpc_id" {
  type = string
}

variable "fargate_profiles" {
  type    = map(any)
  default = {}
}
