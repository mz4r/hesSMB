resource "kubernetes_namespace" "kserve" {
  metadata {
    name = "kserve"
    labels = {
      "control-plane"   = "kserve-controller"
      "istio-injection" = "disabled"
    }
  }
}

resource "kubernetes_resource_quota" "kserve_quota" {
  metadata {
    name      = "kserve-compute-resources"
    namespace = kubernetes_namespace.kserve.metadata[0].name
  }
  spec {
    hard = {
      "requests.cpu"    = "2000m"
      "requests.memory" = "4000Mi"
      "limits.cpu"      = "4000m"
      "limits.memory"   = "8000Mi"
    }
  }
}

# KSERVE APPS (VIA ARGOCD PROVIDER)

resource "argocd_application" "kserve_crd" {
  metadata {
    name      = "kserve-crd"
    namespace = "argocd"
  }

  spec {
    project = "default"
    source {
      repo_url        = "ghcr.io/kserve/charts"
      chart           = "kserve-crd"
      target_revision = "v0.14.1"
    }
    destination {
      server    = "https://kubernetes.default.svc"
      namespace = kubernetes_namespace.kserve.metadata[0].name
    }
    sync_policy {
      automated {
        prune       = true
        self_heal   = true
        allow_empty = false
      }
      sync_options = ["CreateNamespace=true", "ServerSideApply=true"]
    }
  }
}

resource "argocd_application" "kserve_controller" {
  metadata {
    name      = "kserve"
    namespace = "argocd"
  }

  spec {
    project = "default"
    source {
      repo_url        = "ghcr.io/kserve/charts"
      chart           = "kserve"
      target_revision = "v0.14.1"

      helm {
        values = yamlencode({
          kserve = {
            controller = {
              deploymentMode = "RawDeployment"
              replicas       = 1
              resources      = { requests = { cpu = "100m", memory = "256Mi" }, limits = { cpu = "500m", memory = "1Gi" } }
              gateway = {
                domain = "kserve.mz4.re"
                ingressGateway = {
                  className = "traefik"
                }
              }
            }
            modelmesh = { enabled = false }
          }
        })
      }
    }
    destination {
      server    = "https://kubernetes.default.svc"
      namespace = kubernetes_namespace.kserve.metadata[0].name
    }
    sync_policy {
      automated {
        prune     = true
        self_heal = true
      }
      sync_options = ["CreateNamespace=true", "ServerSideApply=true"]
    }
  }

  depends_on = [argocd_application.kserve_crd]
}

# CERTIFICAT WILDCARD
resource "kubernetes_manifest" "kserve_wildcard_cert" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "kserve-wildcard-tls"
      namespace = kubernetes_namespace.kserve.metadata[0].name
    }
    spec = {
      secretName = "kserve-wildcard-tls"
      issuerRef = {
        name = "local-pki-issuer"
        kind = "ClusterIssuer"
      }
      commonName = "*.kserve.mz4.re"
      dnsNames   = ["*.kserve.mz4.re", "kserve.mz4.re"]
    }
  }
}


# MODÈLE SKLEARN-IRIS (CORRIGÉ)
resource "local_file" "sklearn_iris_yaml" {
  content  = <<EOF
apiVersion: "serving.kserve.io/v1beta1"
kind: "InferenceService"
metadata:
  name: "sklearn-iris"
  namespace: "kserve"
  annotations:
    "sidecar.istio.io/inject": "false"
spec:
  predictor:
    model:
      modelFormat:
        name: sklearn
      storageUri: "gs://kfserving-examples/models/sklearn/1.0/model"
EOF
  filename = "${path.module}/sklearn-iris.yaml"
}

resource "null_resource" "apply_sklearn_iris" {
  triggers = {
    manifest_sha1 = sha1(local_file.sklearn_iris_yaml.content)
  }

  provisioner "local-exec" {
    command = "kubectl apply -f ${local_file.sklearn_iris_yaml.filename} --kubeconfig ../../kubeconfig_cluster"
  }

  depends_on = [argocd_application.kserve_controller]
}

resource "kubernetes_manifest" "sklearn_iris_route" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "sklearn-iris-route"
      namespace = kubernetes_namespace.kserve.metadata[0].name
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [{
        match = "Host(`iris.kserve.mz4.re`)"
        kind  = "Rule"
        services = [{
          name = "sklearn-iris-predictor-default"
          port = 80
        }]
      }]
      tls = {
        secretName = "kserve-wildcard-tls"
      }
    }
  }

  depends_on = [null_resource.apply_sklearn_iris]
}



# MODÈLE QWEN
resource "local_file" "qwen_yaml" {
  content  = <<EOF
apiVersion: "serving.kserve.io/v1beta1"
kind: "InferenceService"
metadata:
  name: "qwen-mini"
  namespace: "kserve"
  annotations:
    "sidecar.istio.io/inject": "false"
spec:
  predictor:
    model:
      modelFormat:
        name: huggingface
      # On utilise Qwen 1.5 version 0.5 Milliards de paramètres
      args:
        - --model_name=Qwen/Qwen1.5-0.5B-Chat
        - --task=text-generation
      resources:
        requests:
          cpu: "500m"     # Demande un demi-coeur
          memory: "800Mi" # Demande moins de 1Go de RAM !
        limits:
          cpu: "2000m"
          memory: "2Gi"   # Plafond de sécurité
EOF
  filename = "${path.module}/qwen-mini.yaml"
}

# Étape B : Application via kubectl
resource "null_resource" "apply_qwen" {
  triggers = {
    manifest_sha1 = sha1(local_file.qwen_yaml.content)
  }

  provisioner "local-exec" {
    # Vérifiez toujours le chemin de votre kubeconfig
    command = "kubectl apply -f ${local_file.qwen_yaml.filename} --kubeconfig ../../kubeconfig_cluster"
  }

  depends_on = [argocd_application.kserve_controller]
}

# Étape C : La Route Traefik pour Qwen
resource "kubernetes_manifest" "qwen_route" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "qwen-route"
      namespace = kubernetes_namespace.kserve.metadata[0].name
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [{
        match = "Host(`qwen.kserve.mz4.re`)"
        kind  = "Rule"
        services = [{
          name = "qwen-mini-predictor-default"
          port = 80
        }]
      }]
      tls = {
        secretName = "kserve-wildcard-tls"
      }
    }
  }

  depends_on = [null_resource.apply_qwen]
}