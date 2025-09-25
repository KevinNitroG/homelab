resource "cloudflare_zero_trust_tunnel_cloudflared" "kube" {
  account_id = var.cf_account_id
  name       = "kevblink-kube"
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "kube" {
  account_id = var.cf_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.kube.id
  config = {
    ingress = concat(
      [
        for app_name, endpoint in var.apps :
        {
          hostname = "${app_name}.${var.cf_domain}"
          service  = endpoint
        }
      ],
      [
        {
          service = "http_status:404"
        }
      ]
    )
  }
}
