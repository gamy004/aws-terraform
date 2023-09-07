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

output "ecr_repositories" {
  value = aws_ecr_repository.pipeline
}

output "pipeline_arns" {
  value = { for key, pipeline in aws_codepipeline.pipeline : key => pipeline.arn }
}
