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
# AUTOMATED OIDC & IRSA TRUST CONTROLLER (ADDED)
# ==============================================================================

# 1. Automatically register the cluster's unique identity signature with AWS IAM
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

data "aws_iam_openid_connect_provider" "existing" {
  count = var.create_oidc_provider ? 0 : 1
  url   = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "main" {
  count           = var.create_oidc_provider ? 1 : 0
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.main[0].arn : data.aws_iam_openid_connect_provider.existing[0].arn
  oidc_issuer       = replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")
}

# 2. Create the IAM role that trusts our fresh EKS cluster context dynamically
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

# 3. Automatically grant this target role Secrets Manager access privileges
resource "aws_iam_role_policy_attachment" "secrets_policy" {
  role       = aws_iam_role.secrets_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}