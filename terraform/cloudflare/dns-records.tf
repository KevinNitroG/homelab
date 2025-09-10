resource "cloudflare_dns_record" "apps" {
  for_each = toset(var.apps)

  zone_id = var.cf_zone_id
  name    = "${each.value}.${var.cf_domain}"
  ttl     = 1
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.kube.id}.cfargotunnel.com"
  proxied = true
  comment = "Kube tunnel"
}
