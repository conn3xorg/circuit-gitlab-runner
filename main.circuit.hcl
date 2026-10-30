# Facts give each host's distribution, which picks GitLab's apt or yum
# repository for the runner.
data "conn3x_host" "facts" {
  for_each = var.hosts

  ssh {
    host             = try(each.value.address, each.value)
    host_key         = try(each.value.host_key, null)
    user             = try(each.value.user, var.ssh_user)
    port             = try(each.value.port, var.ssh_port)
    private_key_file = try(each.value.private_key_file, var.ssh_private_key_file)
    jump_hosts       = try(each.value.jump_hosts, null)
    known_hosts_file = var.ssh_known_hosts_file
  }

  lifecycle {
    postcondition {
      condition     = try(each.value.os, self.os_id) == self.os_id
      error_message = "Host ${each.key} is ${self.os_id}, not the ${try(each.value.os, "")} its os says."
    }

    postcondition {
      condition     = self.os_family == "redhat" ? contains(["rocky", "almalinux", "rhel"], self.os_id) : contains(keys(local.codenames), "${self.os_id} ${self.os_version}")
      error_message = "Host ${each.key} runs ${self.os_id} ${self.os_version}. GitLab publishes GitLab Runner packages for Ubuntu 22.04, 24.04 and 26.04, Debian 12 and 13, and Rocky Linux, AlmaLinux and RHEL."
    }
  }
}

locals {
  # A host object's os stands in for the facts of a host created in the
  # same plan, which can't be read until it exists.
  os        = { for name, h in var.hosts : name => try(h.os, data.conn3x_host.facts[name].os_id) }
  family    = { for name, o in local.os : name => contains(["debian", "ubuntu"], o) ? "debian" : "redhat" }
  deb_hosts = { for name, h in var.hosts : name => h if local.family[name] == "debian" }
  codenames = {
    "ubuntu 22.04" = "jammy"
    "ubuntu 24.04" = "noble"
    "ubuntu 26.04" = "resolute"
    "debian 12"    = "bookworm"
    "debian 13"    = "trixie"
  }
  codename = { for name, f in data.conn3x_host.facts : name => lookup(local.codenames, "${f.os_id} ${f.os_version}", "") }

  # GitLab builds every runner package as release 1 of its version.
  package_version = "${var.runner_version}-1"

  config_file = "/etc/gitlab-runner/config.toml"
}

# gitlab-runner depends on gitlab-runner-helper-images of exactly its own
# version. apt only looks at a dependency's newest version, so asked for an
# older gitlab-runner it gives up, and asked to move the helper images on
# its own it removes gitlab-runner. Pinning both to the release makes that
# release the one apt picks for each, and keeps apt upgrade off them.
circuit "apt" {
  hosts = local.deb_hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  step "pin" {
    file {
      path    = "/etc/apt/preferences.d/gitlab-runner"
      content = <<-EOT
        # Written by Conn3x. Changes here are overwritten on the next apply.
        Package: gitlab-runner gitlab-runner-helper-images
        Pin: version ${local.package_version}
        Pin-Priority: 1001
      EOT
    }
  }
}

circuit "runner" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  # apt checks the repository's Release file against the repository key,
  # which expires on 6 February 2028. dnf checks each package against the
  # runner's package signing key, which expires on 26 February 2027.
  step "repo" {
    repository {
      name   = "gitlab-runner"
      url    = local.family[each.key] == "debian" ? "https://packages.gitlab.com/runner/gitlab-runner/${local.os[each.key]}" : "https://packages.gitlab.com/runner/gitlab-runner/el/$releasever/$basearch"
      key    = file("${path.module}/files/${local.family[each.key] == "debian" ? "gitlab-repo.asc" : "gitlab-runner-packages.asc"}")
      suites = local.family[each.key] == "debian" ? [local.codename[each.key]] : null
    }
  }

  # dnf brings the matching helper images along; on apt the pin does.
  step "package" {
    depends_on = [conn3x_file.apt__pin]
    package {
      name    = "gitlab-runner"
      version = local.package_version
    }
  }

  # Registering a runner with an authentication token only checks the token
  # and writes this file, so the circuit writes it whole instead. Write-only,
  # since it holds the token: the plan and state record only an HMAC.
  # GitLab Runner reads the file again within seconds of a change, without
  # a restart.
  step "config" {
    template {
      source      = "${path.module}/templates/config.toml.tftpl"
      destination = local.config_file
      mode        = "0600"
      write_only  = true
      vars = {
        concurrent = var.concurrent
        # One job request at a time leaves the other slots waiting out
        # GitLab's 50-second long poll, and the runner warns about it.
        request_concurrency = min(var.concurrent, 4)
        name                = each.key
        url                 = var.gitlab_url
        token               = var.runner_token
        executor            = var.executor
        docker_image        = var.docker_image
      }
    }
  }

  step "service" {
    service {
      name    = "gitlab-runner"
      enabled = true
      state   = "started"
    }
  }
}
