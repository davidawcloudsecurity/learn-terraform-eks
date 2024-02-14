provider "aws" {
  region = "us-east-1"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}

resource "null_resource" "kubectl" {
  provisioner "local-exec" {
        command = "aws eks update-kubeconfig --region ${var.region}  --name ${var.cluster-name}"
  }
}

variable "cluster-name" {
  default = "terraform-eks-demo"
}

output "cluster-name-output" {
  value = "${var.cluster-name}-value"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

# Setup VPC and Subnet
resource "aws_vpc" "terraform-eks-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "terraform-eks-vpc"
  }
}

# Setup IGW and NAT
resource "aws_internet_gateway" "terraform-eks-igw" {
  vpc_id = aws_vpc.terraform-eks-vpc.id

  tags = {
    Name = "terraform-eks-igw"
  }
}

resource "aws_eip" "terraform-eks-eip" {
  vpc = true

  tags = {
    Name = "terraform-eks-eip"
  }
}

resource "aws_nat_gateway" "terraform-eks-nat" {
  allocation_id = aws_eip.terraform-eks-eip.id
  subnet_id     = aws_subnet.terraform-eks-public-us-east-1a.id

  tags = {
    Name = "terraform-eks-nat"
  }

  depends_on = [aws_internet_gateway.terraform-eks-igw]
}


resource "aws_subnet" "terraform-eks-public-us-east-1a" {
  vpc_id                  = aws_vpc.terraform-eks-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    "Name"                       = "terraform-eks-public-us-east-1a"
    "kubernetes.io/role/elb"     = "1"
    "kubernetes.io/cluster/demo" = "owned"
  }
}

resource "aws_subnet" "terraform-eks-public-us-east-2a" {
  vpc_id                  = aws_vpc.terraform-eks-vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    "Name"                       = "terraform-eks-public-us-east-2a"
    "kubernetes.io/role/elb"     = "1"
    "kubernetes.io/cluster/demo" = "owned"
  }
}

resource "aws_subnet" "terraform-eks-private-us-east-1b" {
  vpc_id            = aws_vpc.terraform-eks-vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    "Name"                            = "terraform-eks-private-us-east-1b"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/demo"      = "owned"
  }
}

resource "aws_subnet" "terraform-eks-private-us-east-2b" {
  vpc_id            = aws_vpc.terraform-eks-vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    "Name"                            = "terraform-eks-private-us-east-2b"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/demo"      = "owned"
  }
}

resource "aws_subnet" "terraform-eks-private-us-east-1c" {
  vpc_id            = aws_vpc.terraform-eks-vpc.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "us-east-1a"

  tags = {
    "Name"                            = "terraform-eks-private-us-east-1c"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/demo"      = "owned"
  }
}

# Setup route table and association
resource "aws_route_table" "terraform-eks-private-rt" {
  vpc_id = aws_vpc.terraform-eks-vpc.id

  route = [
    {
      cidr_block                 = "0.0.0.0/0"
      nat_gateway_id             = aws_nat_gateway.terraform-eks-nat.id
      carrier_gateway_id         = ""
      destination_prefix_list_id = ""
      egress_only_gateway_id     = ""
      gateway_id                 = ""
      instance_id                = ""
      ipv6_cidr_block            = ""
      local_gateway_id           = ""
      network_interface_id       = ""
      transit_gateway_id         = ""
      vpc_endpoint_id            = ""
      vpc_peering_connection_id  = ""
    },
  ]

  tags = {
    Name = "terraform-eks-private-rt"
  }
}

resource "aws_route_table" "terraform-eks-public-rt" {
  vpc_id = aws_vpc.terraform-eks-vpc.id

  route = [
    {
      cidr_block                 = "0.0.0.0/0"
      gateway_id                 = aws_internet_gateway.terraform-eks-igw.id
      nat_gateway_id             = ""
      carrier_gateway_id         = ""
      destination_prefix_list_id = ""
      egress_only_gateway_id     = ""
      instance_id                = ""
      ipv6_cidr_block            = ""
      local_gateway_id           = ""
      network_interface_id       = ""
      transit_gateway_id         = ""
      vpc_endpoint_id            = ""
      vpc_peering_connection_id  = ""
    },
  ]

  tags = {
    Name = "terraform-eks-public-rt"
  }
}

resource "aws_route_table_association" "public-us-east-1a-rta" {
  subnet_id      = aws_subnet.terraform-eks-public-us-east-1a.id
  route_table_id = aws_route_table.terraform-eks-public-rt.id
}

resource "aws_route_table_association" "public-us-east-2a-rta" {
  subnet_id      = aws_subnet.terraform-eks-public-us-east-2a.id
  route_table_id = aws_route_table.terraform-eks-public-rt.id
}

resource "aws_route_table_association" "terraform-eks-private-us-east-1b-rta" {
  subnet_id      = aws_subnet.terraform-eks-private-us-east-1b.id
  route_table_id = aws_route_table.terraform-eks-private-rt.id
}

resource "aws_route_table_association" "terraform-eks-private-us-east-1c-rta" {
  subnet_id      = aws_subnet.terraform-eks-private-us-east-1c.id
  route_table_id = aws_route_table.terraform-eks-private-rt.id
}

# Setup AWS IAM Role for cluster
resource "aws_iam_role" "terraform-eks-role-cluster" {
  name = var.cluster-name

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "terraform-eks-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.terraform-eks-role-cluster.name}"
}

resource "aws_iam_role_policy_attachment" "terraform-eks-cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.terraform-eks-role-cluster.name}"
}

# Setup cluster
resource "aws_eks_cluster" "terraform-eks-cluster" {
  name            = var.cluster-name
  role_arn        = aws_iam_role.terraform-eks-role-cluster.arn

  vpc_config {
    security_group_ids = [
      aws_security_group.terraform-eks-private-facing-sg.id
    ]
    subnet_ids         = [
      aws_subnet.terraform-eks-public-us-east-1a.id,
      aws_subnet.terraform-eks-public-us-east-2a.id,
      aws_subnet.terraform-eks-private-us-east-2b.id,
      aws_subnet.terraform-eks-private-us-east-1b.id,
      aws_subnet.terraform-eks-private-us-east-1c.id
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.terraform-eks-cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.terraform-eks-cluster-AmazonEKSServicePolicy
  ]
}

# Create public facing security group
resource "aws_security_group" "terraform-eks-public-facing-sg" {
  vpc_id = aws_vpc.terraform-eks-vpc.id
  name   = "terraform-eks-public-facing-sg"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    # Allow traffic from public subnet
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {  
    Name = "terraform-eks-public-facing-sg"
  }
}

# Create private facing security group
resource "aws_security_group" "terraform-eks-private-facing-sg" {
  vpc_id = aws_vpc.terraform-eks-vpc.id
  name   = "terraform-eks-private-facing-sg"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
#    cidr_blocks = ["10.0.3.0/24"]
    # Allow traffic from private subnets
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-eks-private-facing-sg"
  }
}

# KIV first, use aws eks cli to update konfig
# Create kubeconfig. This might help me run kubectl within tf
locals {
  kubeconfig = <<KUBECONFIG


apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.terraform-eks-cluster.endpoint}
    certificate-authority-data: ${aws_eks_cluster.terraform-eks-cluster.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws-iam-authenticator
      args:
      - --region
      - "${var.region}"
      - eks
      - get-token
      - --cluster-name
      - "${var.cluster-name}"
      - --output
      - json
        - "token"
        - "-i"       
        command: aws
KUBECONFIG
}

output "kubeconfig" {
  value = "${local.kubeconfig}"
}

# Setup Nodes
resource "aws_iam_role" "terraform-eks-nodes-role" {
  name = "eks-node-group-nodes"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.terraform-eks-nodes-role.name
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.terraform-eks-nodes-role.name
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.terraform-eks-nodes-role.name
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.terraform-eks-nodes-role.name
}

resource "aws_eks_node_group" "private-nodes" {
  cluster_name    = aws_eks_cluster.terraform-eks-cluster.name
  node_group_name = "private-nodes"
  node_role_arn   = aws_iam_role.terraform-eks-nodes-role.arn

  subnet_ids = [
    aws_subnet.terraform-eks-public-us-east-1a.id,
    aws_subnet.terraform-eks-private-us-east-1b.id,
    aws_subnet.terraform-eks-private-us-east-1c.id
  ]

  capacity_type  = "ON_DEMAND"
  instance_types = ["t3.small"]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "general"
  }

  # taint {
  #   key    = "team"
  #   value  = "devops"
  #   effect = "NO_SCHEDULE"
  # }

  launch_template {
    name    = aws_launch_template.eks-with-disks.name
    version = aws_launch_template.eks-with-disks.latest_version
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.nodes-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.nodes-AmazonEC2ContainerRegistryReadOnly,
  ]
}

locals {
  demo-node-userdata = <<USERDATA
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==BOUNDARY=="

--==BOUNDARY==
Content-Type: text/cloud-config; charset="us-ascii"
#!/bin/bash
# Define the path to the sshd_config file
sshd_config="/etc/ssh/sshd_config"

# Define the string to be replaced
old_string="PasswordAuthentication no"
new_string="PasswordAuthentication yes"

# Check if the file exists
if [ -e "$sshd_config" ]; then
    # Use sed to replace the old string with the new string
    sudo sed -i "s/$old_string/$new_string/" "$sshd_config"

    # Check if the sed command was successful
    if [ $? -eq 0 ]; then
        echo "String replaced successfully."
        # Restart the SSH service to apply the changes
        sudo service ssh restart
    else
        echo "Error replacing string in $sshd_config."
    fi
else
    echo "File $sshd_config not found."
fi

echo "123" | passwd --stdin ec2-user
systemctl restart sshd

#Install ssm agent
if [[ $(uname -i) == "aarch64" ]]; then
  echo "arm"
  yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_arm64/amazon-ssm-agent.rpm
else
  echo "amd"
  yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
fi
systemctl start amazon-ssm-agent
--==BOUNDARY==--
USERDATA
}

resource "aws_launch_template" "eks-with-disks" {
  name = "eks-with-disks"
  user_data = "${base64encode(local.demo-node-userdata)}"

  block_device_mappings {
    device_name = "/dev/xvdb"

    ebs {
      volume_size = 8
      volume_type = "gp2"
    }
  }
}



