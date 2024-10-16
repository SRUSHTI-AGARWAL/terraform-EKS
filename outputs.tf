output "VPC-ID" {
  value   = aws_vpc.eks_vpc.id

}
output "EKS-Cluster-ID" {
  value   = aws_eks_cluster.eks_st.id
}

output "Node-group-ID" {
  value       = aws_eks_node_group.eks_node_group.id
}

output "Subnet-ID" {
  value       = [aws_subnet.eks_public_subnets[*].id]
}