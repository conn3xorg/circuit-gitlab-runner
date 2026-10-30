output "config_file" {
  description = "Path of the config.toml the circuit writes on each host."
  value       = local.config_file
}

output "gitlab_url" {
  description = "GitLab instance the runners take jobs from."
  value       = var.gitlab_url
}
