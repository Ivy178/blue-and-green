# 约束 Terraform 版本和 AWS 提供者版本，避免兼容性问题
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0, < 6.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0, < 3.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10.0, < 3.0.0"
    }
  }
  required_version = ">= 1.5.0"
}