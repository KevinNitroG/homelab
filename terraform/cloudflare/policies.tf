resource "cloudflare_zero_trust_list" "admin" {
  account_id = var.cf_account_id
  name       = "admin emails"
  type       = "EMAIL"
  items = [
    { value = "trannguyenthaibinh46@gmail.com" },
    { value = "ntgnguyen563@gmail.com" },
    { value = "dongminhchi9120@gmail.com" },
  ]
}

resource "cloudflare_zero_trust_access_policy" "admin" {
  account_id = var.cf_account_id
  name       = "admin"
  decision   = "allow"
  include = [{
    email_list = {
      id = cloudflare_zero_trust_list.admin.id
    }
  }]
}

