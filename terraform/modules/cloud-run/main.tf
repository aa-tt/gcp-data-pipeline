/**
 * Cloud Run Module
 * Deploys the React UI application to Cloud Run
 */

locals {
  service_name = "data-pipeline-ui-${var.environment}"
  image_name   = "gcr.io/${var.project_id}/data-pipeline-ui:latest"
}

# Cloud Run service for React UI
resource "google_cloud_run_service" "ui" {
  name     = local.service_name
  location = var.region
  project  = var.project_id

  template {
    spec {
      service_account_name = var.service_account
      
      containers {
        image = local.image_name
        
        ports {
          container_port = 8080
        }
        
        env {
          name  = "VITE_API_URL"
          value = var.ingestion_function_url
        }
        
        env {
          name  = "NODE_ENV"
          value = "production"
        }
        
        resources {
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
        }
      }
    }
    
    metadata {
      labels = merge(
        var.labels,
        {
          environment = var.environment
          component   = "ui"
        }
      )
      
      annotations = {
        "autoscaling.knative.dev/maxScale"      = "10"
        "autoscaling.knative.dev/minScale"      = "0"
        "run.googleapis.com/client-name"        = "terraform"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  autogenerate_revision_name = true
}

# IAM policy to allow unauthenticated access (optional)
resource "google_cloud_run_service_iam_member" "public_access" {
  count    = var.allow_unauthenticated ? 1 : 0
  location = google_cloud_run_service.ui.location
  project  = google_cloud_run_service.ui.project
  service  = google_cloud_run_service.ui.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Output for easy access to the URL
output "service_url" {
  description = "URL of the deployed Cloud Run service"
  value       = google_cloud_run_service.ui.status[0].url
}

output "service_name" {
  description = "Name of the Cloud Run service"
  value       = google_cloud_run_service.ui.name
}
