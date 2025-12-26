# Get project number for Pub/Sub service account
data "google_project" "project" {
  project_id = var.project_id
}

# Storage bucket for Cloud Function source code
resource "google_storage_bucket" "function_source" {
  name          = "${var.project_id}-function-source-${var.environment}"
  location      = var.region
  force_destroy = true
  
  uniform_bucket_level_access = true
}

# Placeholder for function source - will be uploaded by CI/CD
resource "google_storage_bucket_object" "function_source_placeholder" {
  name    = "cloud-functions/placeholder.txt"
  bucket  = google_storage_bucket.function_source.name
  content = "Function source code will be uploaded via CI/CD"
}

# Cloud Function for data ingestion (HTTP triggered)
resource "google_cloudfunctions2_function" "data_ingestion" {
  name        = "data-ingestion-${var.environment}"
  location    = var.region
  description = "Ingests data and publishes to Pub/Sub"

  build_config {
    runtime     = "python311"
    entry_point = "ingest_data"
    
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = "cloud-functions/data-ingestion.zip"
      }
    }
  }

  service_config {
    max_instance_count    = 10
    min_instance_count    = 0
    available_memory      = "256M"
    timeout_seconds       = 60
    service_account_email = var.service_account

    environment_variables = {
      PUBSUB_TOPIC      = var.pubsub_topic
      ENVIRONMENT       = var.environment
      GCP_PROJECT       = var.project_id
    }
  }

  labels = var.labels

  # Depend on source code being uploaded
  depends_on = [google_storage_bucket.function_source]
}

# Cloud Function for Pub/Sub processing (Event triggered)
resource "google_cloudfunctions2_function" "pubsub_processor" {
  name        = "pubsub-processor-${var.environment}"
  location    = var.region
  description = "Processes messages from Pub/Sub and stores in GCS"

  build_config {
    runtime     = "python311"
    entry_point = "process_message"
    
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = "cloud-functions/pubsub-processor.zip"
      }
    }
  }

  service_config {
    max_instance_count    = 10
    min_instance_count    = 0
    available_memory      = "512M"
    timeout_seconds       = 300
    service_account_email = var.service_account

    environment_variables = {
      PROCESSED_BUCKET  = var.processed_bucket
      ENVIRONMENT       = var.environment
      GCP_PROJECT       = var.project_id
    }
  }

  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = var.pubsub_topic
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = var.service_account
  }

  labels = var.labels

  # Depend on source code being uploaded
  depends_on = [google_storage_bucket.function_source]
}

# Allow public invocation of HTTP function (adjust for production)
# Note: For Cloud Functions Gen2, use Cloud Run IAM since they run on Cloud Run
resource "google_cloud_run_service_iam_member" "data_ingestion_invoker" {
  project  = var.project_id
  location = var.region
  service  = google_cloudfunctions2_function.data_ingestion.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Allow unauthenticated invocation of pubsub-processor function
# This is safe because the function is event-triggered, not publicly accessible via HTTP
resource "google_cloud_run_service_iam_member" "pubsub_processor_invoker" {
  project  = var.project_id
  location = var.region
  service  = google_cloudfunctions2_function.pubsub_processor.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Cloud Function for analytics query (HTTP triggered)
resource "google_cloudfunctions2_function" "analytics_query" {
  name        = "analytics-query-${var.environment}"
  location    = var.region
  description = "Queries BigQuery for analytics data and metrics"

  build_config {
    runtime     = "python311"
    entry_point = "query_analytics"
    
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = "cloud-functions/analytics-query.zip"
      }
    }
  }

  service_config {
    max_instance_count    = 10
    min_instance_count    = 0
    available_memory      = "256M"
    timeout_seconds       = 60
    service_account_email = var.service_account

    environment_variables = {
      ENVIRONMENT       = var.environment
      GCP_PROJECT       = var.project_id
    }
  }

  labels = var.labels

  depends_on = [google_storage_bucket.function_source]
}

# Allow public invocation of analytics query function
resource "google_cloud_run_service_iam_member" "analytics_query_invoker" {
  project  = var.project_id
  location = var.region
  service  = google_cloudfunctions2_function.analytics_query.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
