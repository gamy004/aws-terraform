# output "database" {
#   sensitive = true
#   value = module.database.instance
# }

# output "private_ips" {
#     value = module.load_balancers.private_ips
# }

# output "db_configs" {
#   value = local.db_configs
# }

# output "backend_configs" {
#   value = var.backend_configs
# }

# output "service_ecs_configs" {
#   value = local.service_ecs_configs
# }

# output "service_definitions" {
#   value = module.service.service_definitions
# }

# output "repo_configs" {
#   value = module.pipeline.repo_configs
# }

# output "ci_configs" {
#   value = module.pipeline.ci_configs
# }

# output "review_configs" {
#   value = module.pipeline.review_configs
# }

# output "pipeline_configs" {
#   value = module.pipeline.pipeline_configs
# }

# output "api_endpoints" {
#   value = module.internal_lb.api_endpoints
# }

# output "has_pipeline_review_stage" {
#   value = local.has_pipeline_review_stage
# }
