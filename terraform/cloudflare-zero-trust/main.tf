terraform {
  required_version = ">= 1.12.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }
}

resource "cloudflare_zero_trust_access_policy" "admin" {
  account_id = var.cf_account_id
  decision   = "allow"
  include = [
    {
      email_list = {
        id = var.admin_email_list
      }
    },
  ]
  name             = "admin"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_access_application" "grafana" {
  account_id = var.cf_account_id
  name       = "grafana"
  destinations = [
    {
      type = "public"
      uri  = "grafana.kevinnitro.id.vn"
    },
  ]
  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.admin.id
      precedence = 1
    },
  ]
  type = "self_hosted"
}

resource "cloudflare_zero_trust_access_application" "cloudbeaver" {
  account_id = var.cf_account_id
  name       = "cloudbeaver"
  destinations = [
    {
      type = "public"
      uri  = "cloudbeaver.kevinnitro.id.vn"
    },
  ]
  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.admin.id
      precedence = 1
    },
  ]
  type = "self_hosted"
}

resource "cloudflare_zero_trust_access_application" "ariang" {
  account_id = var.cf_account_id
  name       = "ariang"
  destinations = [
    {
      type = "public"
      uri  = "ariang.kevinnitro.id.vn"
    },
  ]
  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.admin.id
      precedence = 1
    },
  ]
  type = "self_hosted"
}
