resource "cloudflare_zero_trust_tunnel_cloudflared" "kevblink-kube" {
  account_id = var.cf_account_id
  name       = "kevblink-kube"
  config_src = "cloudflare"
}
