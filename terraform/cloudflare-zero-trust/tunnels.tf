resource "cloudflare_zero_trust_tunnel_cloudflared" "kevblink-kube" {
  account_id = var.cf_account_id
  name       = "kevblink-kube"
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "kevblink-kube" {
  account_id = var.cf_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.kevblink-kube.id
  config = {
    ingress = [
      {
        hostname = "grafana.${var.cf_domain}"
        service  = "http://grafana.grafana:80"
      },
      {
        hostname = "cloudbeaver.${var.cf_domain}"
        service  = "http://cloudbeaver.cloudbeaver:8978"
      },
      {
        hostname = "ariang.${var.cf_domain}"
        service  = "http://ariang.file:80"
      },
      {
        hostname = "metube.${var.cf_domain}"
        service  = "http://metube.file:8081"
      },
      {
        service = "http_status:404"
      }
    ]
  }
}
