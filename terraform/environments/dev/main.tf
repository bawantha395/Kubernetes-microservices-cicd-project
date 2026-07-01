module "foundation" {
  source = "../../modules/aws/foundation"

  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

module "eks" {
  source = "../../modules/aws/eks"

  environment        = var.environment
  cluster_name       = "issue-app"
  kubernetes_version = "1.29"
  
  vpc_id             = module.foundation.vpc_id
  private_subnet_ids = module.foundation.private_subnet_ids

  node_desired_size   = 2
  node_max_size       = 3
  node_min_size       = 1
  node_instance_types = ["t3.medium"]
}

module "database" {
  source                        = "../../modules/aws/database"
  environment                   = var.environment
  db_instance_class             = "db.t3.micro"
  private_subnet_ids            = module.foundation.private_subnet_ids
  vpc_id                        = module.foundation.vpc_id
  db_username                   = var.db_username
  db_password                   = var.db_password
  eks_cluster_security_group_id = module.eks.cluster_security_group_id
}
