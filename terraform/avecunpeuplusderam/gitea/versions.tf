terraform {
  required_providers {
    rancher2 = {
      source  = "rancher/rancher2"
      version = "8.0.0"
    }
  }
}

provider "rancher2" {
  api_url   = var.rancher_url
  token_key = var.rancher_api_token
}

data "rancher2_cluster" "local" {
  name = "local"
}

data  "rancher2_project" "gitea" {
  cluster_id = data.rancher2_cluster.local.id
  name       = "gitea"
}
