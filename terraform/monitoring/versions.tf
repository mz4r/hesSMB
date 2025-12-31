terraform {
  required_providers {
    argocd = {
      source  = "argoproj-labs/argocd"
      version = ">= 7.12.4"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "argocd" {
  server_addr = "argocd.mz4.re:443"
  username    = "admin"
  password    = "3LfgTXnW4lK13jtN"
  insecure    = true
}

provider "kubernetes" {
  config_path = "../../kubeconfig_cluster"
}