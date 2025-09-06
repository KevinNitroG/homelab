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

# NOTE: Terraform conflict schema
# resource "cloudflare_zero_trust_access_application" "kevblink-ssh" {
#   account_id = var.cf_account_id
#   name       = "kevblink-ssh"
#   policies = [
#     {
#       connection_rules = {
#         ssh = {
#           allow_email_alias = false
#           usernames = [
#             "root",
#             "kevinnitro",
#           ]
#         }
#       }
#       id         = var.legacy_admin_email_list
#       precedence = 1
#     },
#   ]
#   target_criteria = [
#     {
#       port     = 22
#       protocol = "SSH"
#       target_attributes = {
#         "hostname" = [
#           "kevblink",
#         ]
#       }
#     },
#   ]
#   type = "infrastructure"
# }

resource "cloudflare_zero_trust_access_application" "kevblink-ssh-browser" {
  account_id = var.cf_account_id
  name       = "kevblink-ssh-browser"
  destinations = [
    {
      type = "public"
      uri  = "kevblink.kevinnitro.id.vn"
    },
  ]
  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.admin.id
      precedence = 1
    },
  ]
  type = "ssh"
}
