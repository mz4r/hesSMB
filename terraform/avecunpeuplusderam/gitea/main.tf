resource "rancher2_catalog_v2" "gitea_repo" {
  cluster_id = data.rancher2_cluster.local.id
  name       = "gitea-charts"
  url        = "https://dl.gitea.com/charts/"
}

resource "rancher2_namespace" "gitea" {
  name        = "gitea"
  project_id  = data.rancher2_project.gitea.id
  description = "Service de gestion de code source (Git)"
}

resource "rancher2_secret_v2" "gitea_tls" {
  cluster_id = data.rancher2_cluster.local.id
  namespace  = rancher2_namespace.gitea.name
  name       = "gitea-tls"
  type       = "kubernetes.io/tls"
  
  data = {
    "tls.crt" = file("../certs/gitea.pem") # Adaptez le chemin
    "tls.key" = file("../certs/gitea.key")
  }
}

resource "rancher2_app_v2" "gitea" {
  cluster_id    = data.rancher2_cluster.local.id
  name          = "gitea"
  namespace     = rancher2_namespace.gitea.name
  repo_name     = rancher2_catalog_v2.gitea_repo.name
  
  chart_name    = "gitea"
  chart_version = "10.1.3"

  # Injection de la configuration externe
  values = file("${path.module}/values/gitea-values.yaml")

  depends_on = [
    rancher2_catalog_v2.gitea_repo,
    rancher2_secret_v2.gitea_tls
  ]
}