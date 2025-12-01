# Cloud Composer (Managed Apache Airflow) environment
resource "google_composer_environment" "data_pipeline" {
  name   = "data-pipeline-${var.environment}"
  region = var.region

  labels = var.labels

  config {
    software_config {
      image_version = "composer-2-airflow-2"

      env_variables = {
        ENVIRONMENT  = var.environment
        GCP_PROJECT  = var.project_id
      }

      pypi_packages = {
        google-cloud-storage   = ""
        google-cloud-bigquery  = ""
        google-cloud-pubsub    = ""
        apache-airflow-providers-google = ""
      }
    }

    workloads_config {
      scheduler {
        cpu        = 0.5
        memory_gb  = 1.875
        storage_gb = 1
        count      = 1
      }
      web_server {
        cpu        = 0.5
        memory_gb  = 1.875
        storage_gb = 1
      }
      worker {
        cpu        = 0.5
        memory_gb  = 1.875
        storage_gb = 1
        min_count  = 1
        max_count  = 3
      }
    }

    environment_size = "ENVIRONMENT_SIZE_SMALL"

    node_config {
      service_account = var.service_account
    }
  }

  # Timeout for creation (can take 20-30 minutes)
  timeouts {
    create = "90m"
    update = "60m"
    delete = "60m"
  }
}
