terraform {
  required_version = ">= 1.12.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5"
    }
  }
}
