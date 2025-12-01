terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Uncomment to use GCS backend for state storage
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "terraform/state"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "storage.googleapis.com",
    "pubsub.googleapis.com",
    "cloudfunctions.googleapis.com",
    "dataproc.googleapis.com",
    "bigquery.googleapis.com",
    "cloudscheduler.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# Conditionally enable Cloud Composer API
resource "google_project_service" "composer_api" {
  count              = var.enable_composer ? 1 : 0
  service            = "composer.googleapis.com"
  disable_on_destroy = false
}

# Service account for the data pipeline
resource "google_service_account" "data_pipeline_sa" {
  account_id   = "data-pipeline-sa-${var.environment}"
  display_name = "Data Pipeline Service Account"
  description  = "Service account for data pipeline operations"
}

# Grant necessary permissions to the service account
resource "google_project_iam_member" "pipeline_permissions" {
  for_each = toset([
    "roles/dataproc.worker",
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser",
    "roles/storage.objectAdmin",
    "roles/pubsub.editor",
    "roles/logging.logWriter",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.data_pipeline_sa.email}"
}

# Modules
module "storage" {
  source = "./modules/storage"

  project_id         = var.project_id
  region             = var.region
  environment        = var.environment
  lifecycle_days     = var.data_bucket_lifecycle_days
  labels             = var.labels
  service_account    = google_service_account.data_pipeline_sa.email

  depends_on = [google_project_service.required_apis]
}

module "pubsub" {
  source = "./modules/pubsub"

  project_id      = var.project_id
  environment     = var.environment
  labels          = var.labels
  service_account = google_service_account.data_pipeline_sa.email

  depends_on = [google_project_service.required_apis]
}

module "bigquery" {
  source = "./modules/bigquery"

  project_id      = var.project_id
  dataset_location = var.bigquery_dataset_location
  environment     = var.environment
  labels          = var.labels
  service_account = google_service_account.data_pipeline_sa.email

  depends_on = [google_project_service.required_apis]
}

module "cloud_functions" {
  source = "./modules/cloud-functions"

  project_id          = var.project_id
  region              = var.region
  environment         = var.environment
  labels              = var.labels
  service_account     = google_service_account.data_pipeline_sa.email
  pubsub_topic        = module.pubsub.raw_data_topic_id
  processed_bucket    = module.storage.processed_bucket_name

  depends_on = [google_project_service.required_apis]
}

module "dataproc" {
  source = "./modules/dataproc"

  project_id         = var.project_id
  region             = var.region
  environment        = var.environment
  labels             = var.labels
  service_account    = google_service_account.data_pipeline_sa.email
  min_instances      = var.dataproc_min_instances
  max_instances      = var.dataproc_max_instances
  staging_bucket     = module.storage.staging_bucket_name

  depends_on = [google_project_service.required_apis]
}

module "composer" {
  count  = var.enable_composer ? 1 : 0
  source = "./modules/composer"

  project_id      = var.project_id
  region          = var.region
  environment     = var.environment
  labels          = var.labels
  service_account = google_service_account.data_pipeline_sa.email
  node_count      = var.composer_node_count
  machine_type    = var.composer_machine_type

  depends_on = [google_project_service.composer_api]
}
