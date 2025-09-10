variable "apps" {
  type = list(string)
  default = [
    "grafana",
    "cloudbeaver",
    "metube",
  ]
}

variable "cf_api_token_zt" {
  description = "Zero Trust:Edit, Access: Apps and Policies:Edit"
  type        = string
}

variable "cf_account_id" {
  type = string
}

variable "cf_domain" {
  type = string
}

variable "cf_zone_id" {
  type = string
}

# IDK how to gen it
variable "admin_email_list" {
  type    = string
  default = "abe6bae1-b22d-40ba-9469-4d6f3cad7c8f"
}
