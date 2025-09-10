resource "cloudflare_zero_trust_access_policy" "admin" {
  account_id = var.cf_account_id
  decision   = "allow"
  include = [{
    email_list = {
      id = var.admin_email_list
    }
  }]
  name = "admin"
}

