variable "apps" {
  type    = list(string)
  default = ["grafana", "cloudbeaver", "ariang", "metube"]
}

resource "cloudflare_zero_trust_access_application" "apps" {
  for_each   = toset(var.apps)
  account_id = var.cf_account_id
  name       = each.value
  type       = "self_hosted"
  destinations = [{
    uri = "${each.value}.${var.cf_domain}"
  }]
  policies = [{
    id = cloudflare_zero_trust_access_policy.admin.id
  }]
}
