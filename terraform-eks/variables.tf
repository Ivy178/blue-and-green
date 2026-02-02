# EKS 集群名称
variable "eks_cluster_name" {
  type        = string
  description = "AWS EKS 集群的名称"
  default     = "jenkins-bluegreen-eks"
}

# AWS 区域
variable "aws_region" {
  type        = string
  description = "AWS 区域"
  default     = "ap-east-1"
}

# EKS 集群版本
variable "eks_cluster_version" {
  type        = string
  description = "EKS 集群版本"
  default     = "1.30"
}

# 供 Jenkins 蓝绿发布使用的 Namespace 名称
variable "jenkins_bluegreen_namespace" {
  type        = string
  description = "供 Jenkins 执行蓝绿发布的专用 Namespace 名称"
  default     = "jenkins-bluegreen-deploy"
}

# EKS 节点组配置（最小/最大/期望节点数）
variable "eks_node_group_desired_size" {
  type        = number
  description = "EKS 节点组期望节点数"
  default     = 2
}

variable "eks_node_group_min_size" {
  type        = number
  description = "EKS 节点组最小节点数"
  default     = 1
}

variable "eks_node_group_max_size" {
  type        = number
  description = "EKS 节点组最大节点数"
  default     = 3
}

# 节点组实例类型
variable "eks_node_group_instance_type" {
  type        = string
  description = "EKS 节点组 EC2 实例类型"
  default     = "t3.medium"
}