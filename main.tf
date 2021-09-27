
provider "google" {
  zone = var.zone
}

data "google_client_config" "default" {
}

data "google_container_cluster" "default" {
  name = var.cluster_name
}

provider "kubernetes" {
  host  = "https://${data.google_container_cluster.default.endpoint}"
  token = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.default.master_auth[0].cluster_ca_certificate,
  )
  experiments {
    manifest_resource = true
  }
}

provider "helm" {
  kubernetes {
    host  = "https://${data.google_container_cluster.default.endpoint}"
    token = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(
      data.google_container_cluster.default.master_auth[0].cluster_ca_certificate,
    )
  }
}

resource "helm_release" "nginx_ingress" {
  name = "nginx-ingress-controller"

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx-ingress-controller"

  set {
    name  = "service.type"
    value = "ClusterIP"
  }
}

resource "helm_release" "operator" {
  name       = "terraform-operator"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "terraform"

  namespace = kubernetes_namespace.demo.metadata[0].name

  depends_on = [
    kubernetes_secret.terraformrc,
    kubernetes_secret.workspacesecrets
  ]
}

resource "kubernetes_namespace" "demo" {
  metadata {
    name = "demo"
  }
}
resource "kubernetes_secret" "workspacesecrets" {
  metadata {
    name      = "workspacesecrets"
    namespace = kubernetes_namespace.demo.metadata[0].name
  }

  data = {
    "GOOGLE_CREDENTIALS" = var.gcp_credentials
    "GOOGLE_PROJECT"     = var.project
    "GOOGLE_REGION"      = var.region
  }
}

resource "kubernetes_secret" "terraformrc" {
  metadata {
    name      = "terraformrc"
    namespace = kubernetes_namespace.demo.metadata[0].name
  }

  data = {
    "credentials" = var.credentials
  }
}