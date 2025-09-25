variable "apps" {
  type = map(string)
  default = {
    cloudbeaver = "http://cloudbeaver.cloudbeaver:8978"
    metube      = "http://metube.files:8081"
    prometheus  = "http://monitoring-kube-prometheus-prometheus.monitoring:9090"
  }
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
