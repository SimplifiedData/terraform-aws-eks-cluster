#============================================
# Get Detail AWS Account
#============================================
data "aws_availability_zones" "available" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
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
