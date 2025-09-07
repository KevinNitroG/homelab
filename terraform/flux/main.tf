terraform {
  required_version = ">= 1.12.0"
  required_providers {
    flux = {
      source  = "fluxcd/flux"
      version = ">= 1.6"
    }
    github = {
      source  = "integrations/github"
      version = ">= 6.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.1"
    }
  }
}

resource "tls_private_key" "tls" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "github_repository_deploy_key" "repo" {
  title      = "Flux deploy key"
  repository = "homelab"
  key        = tls_private_key.tls.public_key_openssh
  read_only  = "false"
}

resource "flux_bootstrap_git" "flux" {
  depends_on         = [github_repository_deploy_key.repo]
  embedded_manifests = true
  path               = "kubernetes/flux/"
  interval           = "10m"
}
