output "kevblink-kube" {
  value       = cloudflare_zero_trust_tunnel_cloudflared.kevblink-kube.metadata
  description = "Kubernetes cloudflare tunnel secret"
  sensitive   = true
}

