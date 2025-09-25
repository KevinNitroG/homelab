resource "cloudflare_dns_record" "apps" {
  for_each = var.apps

  zone_id = var.cf_zone_id
  name    = "${each.key}.${var.cf_domain}"
  ttl     = 1
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.kube.id}.cfargotunnel.com"
  proxied = true
  comment = "Kube tunnel"
}
