# vim: set ft=terraform:

terraform {
  required_version = ">= 1.12.0"
  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 6.6"
    }
  }
}

resource "github_repository" "repo" {
  name                   = var.github_repository
  description            = "KevinNitro's Homelab"
  visibility             = "public"
  auto_init              = false
  vulnerability_alerts   = true
  topics                 = ["homelab", "kubernetes", "flux"]
  allow_merge_commit     = false
  delete_branch_on_merge = true
}

