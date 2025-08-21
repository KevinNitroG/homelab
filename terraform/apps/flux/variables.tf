# vim: set ft=terraform:

variable "kubeconfig" {
  description = "Path to kubeconfig for the target cluster"
  type        = string
  default     = "~/.kube/config"
}

variable "github_username" {
  description = "GitHub username or organization"
  type        = string
  default     = "KevinNitroG"
}

variable "github_repository" {
  description = "GitHub repository"
  type        = string
  default     = "homelab"
}
