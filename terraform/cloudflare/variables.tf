variable "apps" {
  type = list(string)
  default = [
    "cloudbeaver",
    "metube",
    "prometheus"
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
