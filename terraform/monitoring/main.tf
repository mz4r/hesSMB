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

# ==============================================================================
# 3. APP : KUBE PROMETHEUS STACK (ArgoCD)
# ==============================================================================
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
        # On charge vos valeurs personnalisées
        values = file("${path.module}/values/monitoring-values.yaml")
        
        # Optionnel : Forcer le mot de passe admin via Terraform si besoin
        # parameter {
        #   name  = "grafana.adminPassword"
        #   value = "VotreMotDePasse"
        # }
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
      # Crée le namespace s'il n'existe pas (redondance de sécurité)
      sync_options = ["CreateNamespace=true", "ServerSideApply=true"] 
    }
  }

  depends_on = [kubernetes_manifest.grafana_cert]
}

# ==============================================================================
# 4. NAMESPACE LOKI
# ==============================================================================
resource "kubernetes_namespace" "loki" {
  metadata {
    name = "loki"
  }
}

# ==============================================================================
# 5. APP : LOKI (ArgoCD)
# ==============================================================================
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

# ==============================================================================
# 6. ROUTE TRAEFIK (Pour exposer Grafana)
# ==============================================================================
# Ajoutez ceci si votre fichier values.yaml ne configure pas l'Ingress automatiquement
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