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

# Root-level instantiation of modules using structural code mapping
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
  db_password                   = var.db_password
  # ✅ FIXED: Reverted to the valid exported output from your EKS module
  eks_cluster_security_group_id = module.eks.cluster_security_group_id
}

module "eks" {
  source              = "../../modules/aws/eks"
  environment         = var.environment
  cluster_name        = "prod-issue-app-cluster"
  kubernetes_version  = "1.36"
  private_subnet_ids  = module.foundation.private_subnet_ids
  vpc_id              = module.foundation.vpc_id
  node_min_size       = 1
  node_desired_size   = 2
  node_max_size       = 3
  # 🚀 KEPT: Upgraded to t3.medium to double RAM and resolve IP allocation limits
  node_instance_types = ["t3.medium"]
}

module "dns_cdn" {
  source      = "../../modules/aws/dns_cdn"
  environment = var.environment
  domain_name = "tcmslk.me"
  # Note: alb_dns_name should be fetched from the ALB created by the Ingress controller
  # In a real scenario, you might need to use a data source or hardcode it after first run
  alb_dns_name = "k8s-issueapp-microser-xxxxxxxxxx.us-east-1.elb.amazonaws.com"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }
}

# ==============================================================================
# AUTOMATED JWT SECRET CONFIGURATION FOR API GATEWAY
# ==============================================================================

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

# ============================================================================== 
# AUTH SERVICE SUPPORTING SECRETS
# ============================================================================== 

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