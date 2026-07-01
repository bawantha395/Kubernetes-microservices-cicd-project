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

# Keeps your master map intact for advanced logic blocks
output "ecr_repository_urls" {
  value = module.registry.repository_urls
}

# ==============================================================================
# FIX: Added singular flat string output expected by GitHub Actions
# ==============================================================================
output "ecr_repository_url" {
  description = "Singular registry URL target consumed by the GitHub Actions runner"
  # Tries to match var.app_name first; defaults to the first available URL in the map if unmatched
  value       = try(
    module.registry.repository_urls[var.app_name], 
    values(module.registry.repository_urls)[0], 
    ""
  )
}