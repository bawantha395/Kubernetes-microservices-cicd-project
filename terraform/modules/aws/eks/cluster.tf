resource "aws_iam_role" "cluster" {
  name = "${var.environment}-${var.cluster_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_eks_cluster" "main" {
  name     = "${var.environment}-${var.cluster_name}"
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  tags = var.tags

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

# ==============================================================================
# AUTOMATED OIDC & IRSA TRUST CONTROLLER (FIXED)
# ==============================================================================

# 1. Automatically read the cluster's unique identity signature
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# 2. Always create the IAM OIDC Provider link directly (Removed failing conditional lookup)
resource "aws_iam_openid_connect_provider" "main" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# 3. Clean local definitions without tracking conditional variations
locals {
  oidc_provider_arn = aws_iam_openid_connect_provider.main.arn
  oidc_issuer       = replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")
}

# 4. Create the IAM role that trusts our fresh EKS cluster context dynamically
resource "aws_iam_role" "secrets_role" {
  name = "${var.environment}-issue-app-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_issuer}:aud" = "sts.amazonaws.com",
            "${local.oidc_issuer}:sub" = "system:serviceaccount:issue-app:issue-app-sa"
          }
        }
      }
    ]
  })
}

# 5. Automatically grant this target role Secrets Manager access privileges
resource "aws_iam_role_policy_attachment" "secrets_policy" {
  role       = aws_iam_role.secrets_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}