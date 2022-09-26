# Required Google APIs
locals {
  googleapis = ["notebooks.googleapis.com", "compute.googleapis.com", "servicenetworking.googleapis.com", "aiplatform.googleapis.com", ]
}

# Enable required services
resource "google_project_service" "apis" {
  for_each           = toset(local.googleapis)
  project            = "modular-scout-345114"
  service            = each.key
  disable_on_destroy = false
}

# Get project information

data "google_project" "project" {
    project_id = "modular-scout-345114"
}

output "number" {
  value = data.google_project.project.number
}

# Custom Service Account
resource "google_service_account" "custom_sa" {
  account_id   = "custom-sa01"
  display_name = "Custom Service Account"
  project      = var.project_id
}

resource "google_kms_key_ring" "example-keyring" {
  name     = "keyring-example1003"
  location = "us-central1"
  depends_on = [
    google_project_service.apis
  ]
}
resource "google_kms_crypto_key" "secrets" {
  name     = "key1003"
  key_ring = google_kms_key_ring.example-keyring.id
}

resource "google_project_service_identity" "notebooks_identity" {
  provider = google-beta
  project  = data.google_project.project.project_id
  service  = "notebooks.googleapis.com"
}
resource "google_kms_crypto_key_iam_member" "crypto_key" {
  crypto_key_id = google_kms_crypto_key.secrets.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.custom_sa.email}"
}

resource "google_kms_crypto_key_iam_member" "service_identity_compute_iam_crypto_key" {
  crypto_key_id = google_kms_crypto_key.secrets.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.project.number}@compute-system.iam.gserviceaccount.com"
}

resource "google_notebooks_instance" "instance" {
  project  = data.google_project.project.project_id
  name     = "notebook-instance03"
  location = "us-central1-a"
  service_account = google_service_account.custom_sa.email
  no_public_ip    = true
  no_proxy_access = false
  disk_encryption = "CMEK"
  kms_key         = google_kms_crypto_key.secrets.id
  machine_type    = "e2-medium"

  metadata = {
    proxy-mode = "service_account"

  }
  container_image {
    repository = "gcr.io/deeplearning-platform-release/base-cpu"
    tag        = "latest"
  }
}

