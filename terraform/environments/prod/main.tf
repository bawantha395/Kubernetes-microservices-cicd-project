terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Partial Configuration: The pipeline will inject the bucket and dynamo table dynamically
  backend "s3" {
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# ==============================================================================
# DATABASE PASSWORD GENERATOR
# ==============================================================================
resource "random_password" "db_password" {
  length  = 20
  special = false
}

# ==============================================================================
# CORE INFRASTRUCTURE MODULES
# ==============================================================================

module "foundation" {
  source               = "../../modules/aws/foundation"
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

module "registry" {
  source      = "../../modules/aws/registry"
  environment = var.environment
  app_name    = var.app_name
}

module "database" {
  source                        = "../../modules/aws/database"
  environment                   = var.environment
  db_instance_class             = "db.t3.micro"
  private_subnet_ids            = module.foundation.private_subnet_ids
  vpc_id                        = module.foundation.vpc_id
  db_username                   = var.db_username
  db_password                   = random_password.db_password.result
  eks_cluster_security_group_id = module.eks.cluster_security_group_id
}

module "eks" {
  source               = "../../modules/aws/eks"
  environment          = var.environment
  cluster_name         = "prod-issue-app-cluster"
  kubernetes_version   = "1.36"
  private_subnet_ids   = module.foundation.private_subnet_ids
  vpc_id               = module.foundation.vpc_id
  
  # 🚀 THE FIX: Expand to 8 desired nodes to create 32 total pod allocation slots
  node_min_size        = 4
  node_desired_size    = 8  
  node_max_size        = 10
  node_instance_types  = ["t3.micro"] # Stays 100% within your Free Tier account policy
  create_oidc_provider = false
}

module "dns_cdn" {
  source      = "../../modules/aws/dns_cdn"
  environment = var.environment
  domain_name = "tcmslk.me"
  alb_dns_name = "k8s-issueapp-microser-7dd78c7c61-109561598.us-east-1.elb.amazonaws.com"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }
}

# ==============================================================================
# AUTOMATED AWS SECRETS MANAGER PROVISIONING
# ==============================================================================

# --- API GATEWAY JWT SECRET ---
resource "random_password" "jwt_secret" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "jwt" {
  name                    = "${var.environment}/game/jwt"
  description             = "Automatically managed JWT Token for API Gateway"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "jwt_value" {
  secret_id     = aws_secretsmanager_secret.jwt.id
  secret_string = jsonencode({
    secret = random_password.jwt_secret.result
  })
}

# --- AUTH SERVICE BOOTSTRAP ADMIN CREDENTIALS ---
resource "random_password" "admin_password" {
  length  = 20
  special = false
}

resource "aws_secretsmanager_secret" "auth_admin" {
  name                    = "${var.environment}/issue/admin"
  description             = "Admin bootstrap credentials for auth-service"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "auth_admin_value" {
  secret_id     = aws_secretsmanager_secret.auth_admin.id
  secret_string = jsonencode({
    email    = "admin@tcmslk.me"
    password = random_password.admin_password.result
  })
}

# --- AUTH SERVICE LIVE MAIL SMTP LINK ---
resource "aws_secretsmanager_secret" "ses" {
  name                    = "${var.environment}/issue/ses"
  description             = "SES SMTP credentials for auth-service"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "ses_value" {
  secret_id     = aws_secretsmanager_secret.ses.id
  secret_string = jsonencode({
    username = "REPLACE_WITH_SES_SMTP_USERNAME"
    password = "REPLACE_WITH_SES_SMTP_PASSWORD"
  })
}

# ==============================================================================
# ROOT OUTPUTS FOR GITHUB ACTIONS RUNNER ACCESS
# ==============================================================================

# 1. Exposes the master map collection to the state ecosystem
output "repository_urls" {
  description = "Map of ECR repository names to their respective registry URLs"
  value       = module.registry.repository_urls
}

# 2. Flattened primitive string fallbacks to prevent pipeline -raw parsing crashes.
# Uses try() lookups to handle both prefix variations ('auth-service' vs 'prod-auth-service') seamlessly.
output "auth_service_ecr_url" {
  description = "Direct URL for the authentication service ECR repository"
  value       = try(module.registry.repository_urls["auth-service"], module.registry.repository_urls["prod-auth-service"], "")
}

output "issue_service_ecr_url" {
  description = "Direct URL for the core issue tracking service ECR repository"
  value       = try(module.registry.repository_urls["issue-service"], module.registry.repository_urls["prod-issue-service"], "")
}

output "api_gateway_ecr_url" {
  description = "Direct URL for the edge routing api-gateway ECR repository"
  value       = try(module.registry.repository_urls["api-gateway"], module.registry.repository_urls["prod-api-gateway"], "")
}

output "frontend_service_ecr_url" {
  description = "Direct URL for the client-facing UI frontend-service ECR repository"
  value       = try(module.registry.repository_urls["frontend-service"], module.registry.repository_urls["prod-frontend-service"], "")
}