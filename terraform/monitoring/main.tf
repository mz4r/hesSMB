resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "kubernetes_manifest" "grafana_cert" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "grafana-tls"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
    }
    spec = {
      secretName = "grafana-tls"
      issuerRef = {
        name = "local-pki-issuer" # Votre issuer existant
        kind = "ClusterIssuer"
      }
      commonName = "grafana.mz4.re" # Adaptez votre domaine
      dnsNames   = ["grafana.mz4.re"]
    }
  }
}

resource "argocd_application" "monitoring" {
  metadata {
    name      = "monitoring-stack"
    namespace = "argocd"
  }

  spec {
    project = "default"

    source {
      repo_url        = "https://prometheus-community.github.io/helm-charts"
      chart           = "kube-prometheus-stack"
      target_revision = "68.3.0" # Version demandée

      helm {
        values = file("${path.module}/values/monitoring-values.yaml")
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
    }

    sync_policy {
      automated {
        prune     = true
        self_heal = true
      }
      sync_options = ["CreateNamespace=true", "ServerSideApply=true"] 
    }
  }

  depends_on = [kubernetes_manifest.grafana_cert]
}

resource "kubernetes_namespace" "loki" {
  metadata {
    name = "loki"
  }
}

resource "argocd_application" "loki" {
  metadata {
    name      = "loki"
    namespace = "argocd"
  }

  spec {
    project = "default"

    source {
      repo_url        = "https://grafana.github.io/helm-charts"
      chart           = "loki"
      target_revision = "6.6.2" # Version demandée

      helm {
        values = file("${path.module}/values/loki-values.yaml")
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = kubernetes_namespace.loki.metadata[0].name
    }

    sync_policy {
      automated {
        prune     = true
        self_heal = true
      }
      sync_options = ["CreateNamespace=true"]
    }
  }
}

resource "kubernetes_manifest" "grafana_route" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "grafana-route"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [{
        match = "Host(`grafana.mz4.re`)"
        kind  = "Rule"
        services = [{
          name = "monitoring-stack-grafana"
          port = 80
        }]
      }]
      tls = {
        secretName = "grafana-tls"
      }
    }
  }
  
  depends_on = [argocd_application.monitoring]
}