output "repo_configs" {
  value = var.configs.repo_configs
}

output "ci_configs" {
  value = local.ci_configs
}

output "review_configs" {
  value = local.review_configs
}

output "pipeline_configs" {
  value = local.pipeline_configs
}
