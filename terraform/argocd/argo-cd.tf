resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}


resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.46.0"
  
  values = [
    file("./values/argo-cd.yml")
  ]

  depends_on = [
  ]
}

resource "kubernetes_namespace" "keel" {
  metadata {
    name = "keel"
  }
}

resource "helm_release" "keel" {
  name       = "keel"
  namespace  = "keel"

  repository = "https://charts.keel.sh"
  chart      = "keel"
  version    = "1.0.5"

  values = [
    file("./values/keel.yml")
  ]

  depends_on = [
    helm_release.argocd,
  ]
}

resource "kubernetes_manifest" "keel_cert" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "keel-tls"
      namespace = "keel"
    }
    spec = {
      secretName = "keel-tls"
      issuerRef = {
        name = "local-pki-issuer"
        kind = "ClusterIssuer"
      }
      commonName = "keel.mz4.re"
      dnsNames   = ["keel.mz4.re"]
    }
  }
  depends_on = [helm_release.keel]
}

resource "kubernetes_manifest" "keel_route" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "keel-route"
      namespace = "keel"
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [{
        match = "Host(`keel.mz4.re`)"
        kind  = "Rule"
        services = [{
          name = "keel" # Nom du service créé par le chart Helm
          port = 9300   # Port de l'UI Keel
        }]
      }]
      tls = {
        secretName = "keel-tls"
      }
    }
  }
  depends_on = [helm_release.keel]
}