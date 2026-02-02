# 1. 配置 AWS 提供者
provider aws {
  region = var.aws_region
}

# 2. 快速创建 VPC（使用 AWS 官方 Terraform 模块，EKS 必须依赖 VPC子网）
# 如需自定义 VPC，可替换为自己的 VPC 配置
module vpc {
  source  = terraform-aws-modulesvpcaws
  version = = 5.0.0,  6.0.0

  name = ${var.eks_cluster_name}-vpc
  cidr = 10.0.0.016

  azs             = [${var.aws_region}a, ${var.aws_region}b]
  private_subnets = [10.0.1.024, 10.0.2.024]
  public_subnets  = [10.0.101.024, 10.0.102.024]

  enable_nat_gateway = true
  single_nat_gateway = true

  # 标签：便于资源识别
  tags = {
    Environment = Production
    Purpose     = Jenkins BlueGreen Deploy EKS
  }
}

# 3. 创建 EKS 集群
resource aws_eks_cluster eks_cluster {
  name     = var.eks_cluster_name
  version  = var.eks_cluster_version
  role_arn = aws_iam_role.eks_cluster_role.arn

  # 配置 VPC 配置（子网、安全组）
  vpc_config {
    subnet_ids     = module.vpc.private_subnets
    endpoint_private_access = true  # 私有端点（生产环境推荐）
    endpoint_public_access  = true   # 公网端点（便于测试）
  }

  # 标签
  tags = {
    Environment = Production
    Purpose     = Jenkins BlueGreen Deploy EKS
  }
}

# 4. 创建 EKS 集群 IAM 角色（EKS 集群所需权限）
resource aws_iam_role eks_cluster_role {
  name = ${var.eks_cluster_name}-cluster-role

  assume_role_policy = jsonencode({
    Version = 2012-10-17
    Statement = [
      {
        Action = stsAssumeRole
        Effect = Allow
        Principal = {
          Service = eks.amazonaws.com
        }
      }
    ]
  })
}

# 5. 附加 EKS 集群默认托管策略
resource aws_iam_role_policy_attachment eks_cluster_policy {
  policy_arn = arnawsiamawspolicyAmazonEKSClusterPolicy
  role       = aws_iam_role.eks_cluster_role.name
}

# 6. 创建 EKS 节点组 IAM 角色（节点所需权限）
resource aws_iam_role eks_node_group_role {
  name = ${var.eks_cluster_name}-node-group-role

  assume_role_policy = jsonencode({
    Version = 2012-10-17
    Statement = [
      {
        Action = stsAssumeRole
        Effect = Allow
        Principal = {
          Service = ec2.amazonaws.com
        }
      }
    ]
  })
}

# 7. 附加节点组所需托管策略
resource aws_iam_role_policy_attachment eks_node_group_policy_1 {
  policy_arn = arnawsiamawspolicyAmazonEKSWorkerNodePolicy
  role       = aws_iam_role.eks_node_group_role.name
}

resource aws_iam_role_policy_attachment eks_node_group_policy_2 {
  policy_arn = arnawsiamawspolicyAmazonEKS_CNI_Policy
  role       = aws_iam_role.eks_node_group_role.name
}

resource aws_iam_role_policy_attachment eks_node_group_policy_3 {
  policy_arn = arnawsiamawspolicyAmazonEC2ContainerRegistryReadOnly
  role       = aws_iam_role.eks_node_group_role.name
}

# 8. 创建 EKS 节点组（实际运行 Pod 的节点）
resource aws_eks_node_group eks_node_group {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = ${var.eks_cluster_name}-node-group
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = module.vpc.private_subnets

  desired_size = var.eks_node_group_desired_size
  min_size     = var.eks_node_group_min_size
  max_size     = var.eks_node_group_max_size

  instance_types = [var.eks_node_group_instance_type]
  disk_size      = 50  # 磁盘大小（GB）
  ami_type       = AL2_x86_64  # Amazon Linux 2 节点 AMI

  tags = {
    Environment = Production
    Purpose     = Jenkins BlueGreen Deploy EKS
  }
}

# 9. 配置 Kubernetes 提供者（用于创建 K8s Namespace）
# 依赖 EKS 集群创建完成，获取 kubeconfig 配置
provider kubernetes {
  host                   = aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks_auth.token
}

# 10. 获取 EKS 集群认证令牌（用于 Kubernetes 提供者认证）
data aws_eks_cluster_auth eks_auth {
  name = aws_eks_cluster.eks_cluster.name
}

# 11. 创建供 Jenkins 蓝绿发布使用的专用 Namespace
resource kubernetes_namespace jenkins_bluegreen_ns {
  metadata {
    name = var.jenkins_bluegreen_namespace
    labels = {
      # 添加标签便于后续筛选和管理
      purpose     = jenkins-bluegreen-deploy
      environment = production
      managed-by  = terraform
    }
  }

  # 依赖节点组创建完成，避免 Namespace 创建时集群未就绪
  depends_on = [aws_eks_node_group.eks_node_group]
}