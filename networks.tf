# Tag VPC, Tested on awscli 2.9.8
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

