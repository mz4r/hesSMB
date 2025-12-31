variable "rancher_url" {
  description = "URL of Rancher Server."
  type        = string
  default     = "https://rancher.mz4.re"
}

variable "rancher_api_token" {
  description = "Token key for connection to Rancher."
  type        = string
  sensitive = true
  default     = "token-684gp:tgb95zrhgwh5l2zr6q9gld95jgg8w9mh62zsx6tkn2ctscx4g2pjth"
}