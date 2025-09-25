resource "cloudflare_zero_trust_access_application" "kube" {
  for_each = var.apps

  account_id = var.cf_account_id
  name       = each.key
  type       = "self_hosted"
  destinations = [{
    uri = "${each.key}.${var.cf_domain}"
  }]
  policies = [{
    id = cloudflare_zero_trust_access_policy.admin.id
  }]
}
