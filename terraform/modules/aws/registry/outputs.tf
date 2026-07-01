# ==============================================================================
# FIXED: ITERATING OVER MULTIPLE ECR REPOSITORY URLS
# ==============================================================================

output "repository_urls" {
  description = "Map of ECR repository names to their respective registry URLs"
  value       = { for k, v in aws_ecr_repository.main : k => v.repository_url }
}