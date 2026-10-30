variable "port" {
  type    = number
  default = 2308
}

# Where your GitLab is, such as http://192.168.1.30 for circuit-gitlab on
# your network.
variable "gitlab_url" {
  type    = string
  default = "https://gitlab.example.com"
}

# Pass it at run time, such as with TF_VAR_runner_token.
variable "runner_token" {
  type      = string
  ephemeral = true
  sensitive = true
}

module "gitlab_runner" {
  source = "../.."

  hosts                = { box = "127.0.0.1" }
  ssh_port             = var.port
  ssh_private_key_file = "./id_ed25519"
  ssh_known_hosts_file = "./known_hosts"

  gitlab_url   = var.gitlab_url
  runner_token = var.runner_token
  concurrent   = 2
}

output "config_file" {
  value = module.gitlab_runner.config_file
}
