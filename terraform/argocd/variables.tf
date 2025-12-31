variable "argocd_version" {
  description = "Argocd version"
  type        = string
  default     = "2.10.4"
}

variable "argocd_url" {
  description = "URL of Argo CD."
  type        = string
  default     = "argocd.mz4.re"
}
