provider "aws" {
  region = var.aws_region
  use_fips_endpoint = true
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
}

provider "github" {}
# filter AZs
data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_support = "true"
  enable_dns_hostnames = "true"
  # ipv6_cidr_block = "2001:db8:1234::/56"
  # ipv6_ipam_pool_id = resource.aws_vpc_ipam_pool.os_vpc_public_parent_pool.id
  tags = {
    Name = "main"
  }
}
resource "aws_vpc_security_group_ingress_rule" "eks_allow_ssh" {
  security_group_id = aws_security_group.web-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_security_group" "web-sg" {
  name        = "${resource.aws_vpc.main.id}-web-eks"
  description = "Web Traffic within EKS"
  vpc_id      = resource.aws_vpc.main.id
  tags = {
    Name = "${resource.aws_vpc.main.id}-web-sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "eks_allow_web" {
  security_group_id = aws_security_group.web-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
resource "aws_vpc_security_group_ingress_rule" "s3demo_allow_ssl" {
  security_group_id = aws_security_group.web-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}
resource "aws_vpc_security_group_ingress_rule" "s3demo_allow_http" {
  security_group_id = aws_security_group.web-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "s3demo_allow_ssl_out" {
  security_group_id = aws_security_group.web-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}
resource "aws_vpc_security_group_egress_rule" "s3demo_allow_http_out" {
  security_group_id = aws_security_group.web-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}



resource "aws_internet_gateway" "internet" {}

resource "aws_internet_gateway_attachment" "internet-attach" {
  internet_gateway_id = aws_internet_gateway.internet.id
  vpc_id              = aws_vpc.main.id
}

resource "aws_subnet" "sub-pub1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.3.0/24"
  assign_ipv6_address_on_creation = "false"
  map_public_ip_on_launch = "true"
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "sub-pub1"
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.clusterName}" = "owned"
  }
}

resource "aws_route_table" "public_rt" {
  depends_on = [resource.aws_internet_gateway_attachment.internet-attach]
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet.id
  }

  tags = {
    Name = "public_rt"
  }
}

resource "aws_route_table_association" "public_rt_assoc_sub-pub1" {
  subnet_id      = aws_subnet.sub-pub1.id
  route_table_id = aws_route_table.public_rt.id
}


resource "aws_network_interface" "public_s3handler" {
  # depends_on =  [resources.aws_subnet.subc, resource.aws_security_group.os_public_proxy_sg]
  subnet_id   = aws_subnet.suba.id
  security_groups = [resource.aws_security_group.web-sg.id]
  tags = {
    Name = "primary_network_interface"
  }
}

data "aws_iam_policy_document" "public_s3handler_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
resource "aws_iam_policy" "s3_admin_policy" {
  name = "policy-381966"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:*"]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}
resource "aws_iam_role" "public_instance_role" {
  name               = "public_instance_role"
  assume_role_policy = data.aws_iam_policy_document.public_s3handler_assume_role_policy.json
}
resource "aws_iam_group" "instance_iamgroup" {
  name = "test-group"
}
resource "aws_iam_group_policy_attachment" "instance-iam-attach" {
  group      = aws_iam_group.instance_iamgroup.name
  policy_arn = aws_iam_policy.s3_admin_policy.arn
}
resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.public_instance_role.name
  policy_arn = aws_iam_policy.s3_admin_policy.arn
}
resource "aws_iam_instance_profile" "public_instance_profile" {
  name = "public_instance_profile"
  role = aws_iam_role.public_instance_role.name
}
locals {
  data-ebs-volume1 = "/dev/xvdb"
  data-dir-base = "/var/lib/s3-files"

}
resource "aws_instance" "public_linux" {
  ami           = var.instance_ami
  availability_zone = "${var.aws_region}a"
  instance_type = "t2.micro"
  key_name = var.ssh_key_pair
  iam_instance_profile = "public_instance_profile"
  user_data_replace_on_change = "true"
  root_block_device {
    encrypted = true
    volume_size = 40
  }
  # user_data depends on this drive getting mounted, so dont use a separate ebs_volume and attachment resources
  ebs_block_device {
    device_name = "${local.data-ebs-volume1}"
    encrypted = true
    volume_size = 40
    volume_type = "gp3"
  }
  network_interface {
    network_interface_id = aws_network_interface.public_s3handler.id
    device_index         = 0
  }
  metadata_options {
    http_endpoint = "enabled"
  }
  user_data = <<-EOL
  #!/bin/bash -xe
  yum install -y java-17-amazon-corretto-headless.x86_64

  mkdir -p ${local.data-dir-base}
  mkfs.ext4 ${local.data-ebs-volume1}
  mount ${local.data-ebs-volume1} ${local.data-dir-base}
  
  java -version
  EOL
}