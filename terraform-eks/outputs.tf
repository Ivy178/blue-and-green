# EKS 集群名称
output "eks_cluster_name" {
  description = "AWS EKS 集群名称"
  value       = aws_eks_cluster.eks_cluster.name
}

# EKS 集群端点
output "eks_cluster_endpoint" {
  description = "AWS EKS 集群 API 端点"
  value       = aws_eks_cluster.eks_cluster.endpoint
}

# EKS 集群版本
output "eks_cluster_version" {
  description = "AWS EKS 集群版本"
  value       = aws_eks_cluster.eks_cluster.version
}

# Jenkins 蓝绿发布专用 Namespace 名称
output "jenkins_bluegreen_namespace" {
  description = "供 Jenkins 蓝绿发布使用的 Namespace 名称"
  value       = kubernetes_namespace.jenkins_bluegreen_ns.metadata[0].name
}

# EKS 节点组名称
output "eks_node_group_name" {
  description = "EKS 节点组名称"
  value       = aws_eks_node_group.eks_node_group.node_group_name
}

# Kubeconfig 配置（简化版，便于本地连接）
output "eks_kubeconfig_snippet" {
  description = "EKS 集群 kubeconfig 配置片段（需替换 ~/.kube/config 或单独保存）"
  value = <<EOT
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${aws_eks_cluster.eks_cluster.certificate_authority[0].data}
    server: ${aws_eks_cluster.eks_cluster.endpoint}
  name: ${var.eks_cluster_name}
contexts:
- context:
    cluster: ${var.eks_cluster_name}
    user: ${var.eks_cluster_name}-user
  name: ${var.eks_cluster_name}
current-context: ${var.eks_cluster_name}
kind: Config
preferences: {}
users:
- name: ${var.eks_cluster_name}-user
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws
      args:
      - eks
      - get-token
      - --cluster-name
      - ${var.eks_cluster_name}
      - --region
      - ${var.aws_region}
EOT
}