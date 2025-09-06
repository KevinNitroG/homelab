provider "flux" {
  kubernetes = {
    config_path = var.kubeconfig
  }
  git = {
    url = "ssh://git@github.com/${var.github_username}/${var.github_repository}.git"
    ssh = {
      username    = "git"
      private_key = tls_private_key.tls.private_key_pem
    }
  }
}
