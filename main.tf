#Provider
provider "aws"{

region="ap-south-1"
}

#vpc
resource "aws_vpc" "eks_vpc"{
cidr_block = var.vpc_cidr_block
tags = {

name= var.vpc_name
}
}

#subnets
resource "aws_subnet" "eks_public_subnets" {
count = 2
vpc_id = aws_vpc.eks_vpc.id

cidr_block = cidrsubnet(aws_vpc.eks_vpc.cidr_block,8,count.index)
availability_zone = element(["ap-south-1a","ap-south-1b"],count.index)
map_public_ip_on_launch= true
tags = {

Name= "${var.vpc_subnet_name}-${count.index}"
}
}

#Security-group

resource "aws_security_group" "eks_cluster_security_group"{
vpc_id=aws_vpc.eks_vpc.id

egress{
cidr_blocks = ["0.0.0.0/0"]
from_port = 0
to_port = 0
protocol = "-1"
}

tags = {

name= var.cluster_sg_name
}
}

#Ingress rules
resource "aws_security_group" "eks_node_security_group"{
vpc_id=aws_vpc.eks_vpc.id

ingress{

cidr_blocks = ["0.0.0.0/0"]
from_port = 0
to_port = 0
protocol = "-1"
}

egress{
cidr_blocks = ["0.0.0.0/0"]
from_port = 0
to_port = 0
protocol = "-1"
}

tags = {
    Name= var.node_sg_name
}
}


# IGW
resource "aws_internet_gateway" "eks_igw"{
vpc_id = aws_vpc.eks_vpc.id
tags = {
name = var.igw
}
}

#Route table for public subnets
resource "aws_route_table" "eks_rt" {
vpc_id = aws_vpc.eks_vpc.id

route{
cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.eks_igw.id

}

tags = {
Name = var.rt
}
}
#Route Table association
resource "aws_route_table_association" "rta"{
count= 2
route_table_id= aws_route_table.eks_rt.id
subnet_id = aws_subnet.eks_public_subnets[count.index].id
}

# ==== EKS Creation ===

#EKS
resource "aws_eks_cluster" "eks_st"{
name = var.eks
role_arn = aws_iam_role.eks_cluster_role.arn

vpc_config  {
subnet_ids= aws_subnet.eks_public_subnets[*].id
security_group_ids = [aws_security_group.eks_cluster_security_group.id]
}
}


resource "aws_eks_node_group" "eks_node_group"{
cluster_name = aws_eks_cluster.eks_st.name
node_group_name = var.eks_ng
node_role_arn = aws_iam_role.eks_cluster_node_role.arn
subnet_ids = aws_subnet.eks_public_subnets[*].id

scaling_config {

    desired_size = 2
    max_size     = 2
    min_size     = 2
}
instance_types = ["t2.medium"]
remote_access {
    ec2_ssh_key = var.ssh_key_name
    source_security_group_ids = [aws_security_group.eks_node_security_group.id]
  }
}

resource "aws_iam_role" "eks_cluster_role"{
name = "${var.eks}-cluster-role"

assume_role_policy = <<EOF
{
"Version" : "2012-10-17",
"Statement": [
{
    "Effect":"Allow",
    "Principal":{
    "Service": "eks.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eks_cluster_role_policy_attachment"{
role = aws_iam_role.eks_cluster_role.name
policy_arn= "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

#Node-Group Role

resource "aws_iam_role" "eks_cluster_node_role"{
name = "${var.eks_ng}-node-role"

assume_role_policy = <<EOF
{
"Version" : "2012-10-17",
"Statement": [
{
    "Effect":"Allow",
    "Principal":{
    "Service": "ec2.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }
 ]
}
EOF
}

# Node-group Policy attachment
resource "aws_iam_role_policy_attachment" "eks_cluster_node_group_role_policy"{
role = aws_iam_role.eks_cluster_node_role.name
policy_arn= "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "eks_cluster_node_group_cni_policy"{
role = aws_iam_role.eks_cluster_node_role.name
policy_arn= "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "eks_cluster_node_group_registry_policy"{
role = aws_iam_role.eks_cluster_node_role.name
policy_arn= "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}


# to create an ec2 only with Admin  access 

# resource "aws_iam_role_policy_attachment" "iam-policy" {
#   role = aws_iam_role.iam-role.name
#   # Just for testing purpose, don't try to give administrator access
#   policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
# }