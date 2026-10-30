variable "hosts" {
  type        = any
  description = "Hosts to configure: a map of names to addresses, or to host objects with an address and optional host_key, user, port, private_key_file, jump_hosts or os."

  validation {
    condition     = alltrue([for h in var.hosts : contains(["debian", "ubuntu", "rocky", "almalinux", "rhel"], try(h.os, "debian"))])
    error_message = "A host object's os must be one of debian, ubuntu, rocky, almalinux or rhel. GitLab Runner packages for Fedora stop at Fedora 44, so this circuit leaves Fedora out."
  }
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "User to log in as."
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "SSH port."
}

variable "ssh_private_key_file" {
  type        = string
  default     = null
  description = "Path to a private key. When null, Conn3x uses the SSH agent."
}

variable "ssh_known_hosts_file" {
  type        = string
  default     = null
  description = "known_hosts file to check host keys against. When null, ~/.ssh/known_hosts."
}

variable "ssh_become" {
  type        = bool
  default     = false
  description = "Run commands as root through sudo."
}

variable "gitlab_url" {
  type        = string
  description = "Address of the GitLab instance the runners take jobs from, such as \"https://gitlab.example.com\"."

  validation {
    condition     = can(regex("^https?://[A-Za-z0-9.-]+(:[0-9]{1,5})?(/[A-Za-z0-9._~/-]*)?$", var.gitlab_url))
    error_message = "gitlab_url must be an http or https URL such as \"https://gitlab.example.com\"."
  }
}

variable "runner_token" {
  type        = string
  ephemeral   = true
  sensitive   = true
  description = "Runner authentication token, starting glrt-, from creating a runner in GitLab. Pass it at run time with -var or TF_VAR_runner_token; it never reaches state or the plan."

  validation {
    condition     = can(regex("^glrt-[A-Za-z0-9._-]+$", var.runner_token))
    error_message = "runner_token must be a runner authentication token, starting glrt-. Registration tokens (GR1348941...) belong to GitLab's old, deprecated registration flow, which this circuit doesn't use."
  }
}

variable "runner_version" {
  type        = string
  default     = "19.5.2"
  description = "GitLab Runner release to install, such as \"19.5.2\". Raising it upgrades the runner in place. Keep it within a minor release or so of your GitLab."

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.runner_version))
    error_message = "runner_version must be a release number such as \"19.5.2\"."
  }
}

variable "executor" {
  type        = string
  default     = "shell"
  description = "How the runner runs jobs: \"shell\", on the host as the gitlab-runner user, or \"docker\", each job in a container, which needs Docker Engine on the host."

  validation {
    condition     = contains(["shell", "docker"], var.executor)
    error_message = "executor must be \"shell\" or \"docker\"."
  }
}

variable "concurrent" {
  type        = number
  default     = 1
  description = "Most jobs each host runs at once."

  validation {
    condition     = var.concurrent >= 1 && floor(var.concurrent) == var.concurrent
    error_message = "concurrent must be a whole number, 1 or more."
  }
}

variable "docker_image" {
  type        = string
  default     = "alpine:3.24"
  description = "Image the docker executor runs a job in when its .gitlab-ci.yml names none."

  validation {
    condition     = can(regex("^[^\\s\"\\\\]+$", var.docker_image))
    error_message = "docker_image must be an image reference such as \"alpine:3.24\", with no spaces or quotes."
  }
}
