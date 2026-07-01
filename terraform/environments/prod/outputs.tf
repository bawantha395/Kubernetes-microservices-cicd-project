output "vpc_id" {
  value = module.foundation.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "database_endpoint" {
  value = module.database.db_endpoint
}

output "ecr_repository_urls" {
  value = module.registry.repository_urls
}
