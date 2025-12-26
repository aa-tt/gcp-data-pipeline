output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP Region"
  value       = var.region
}

output "service_account_email" {
  description = "Service account email for the data pipeline"
  value       = google_service_account.data_pipeline_sa.email
}

# Storage outputs
output "raw_data_bucket" {
  description = "Bucket for raw data storage"
  value       = module.storage.raw_bucket_name
}

output "processed_data_bucket" {
  description = "Bucket for processed data storage"
  value       = module.storage.processed_bucket_name
}

output "staging_bucket" {
  description = "Bucket for staging data and temporary files"
  value       = module.storage.staging_bucket_name
}

# Pub/Sub outputs
output "raw_data_topic" {
  description = "Pub/Sub topic for raw data ingestion"
  value       = module.pubsub.raw_data_topic_id
}

output "processed_data_topic" {
  description = "Pub/Sub topic for processed data notifications"
  value       = module.pubsub.processed_data_topic_id
}

# BigQuery outputs
output "bigquery_dataset" {
  description = "BigQuery dataset for analytics"
  value       = module.bigquery.dataset_id
}

output "bigquery_raw_table" {
  description = "BigQuery table for raw data"
  value       = module.bigquery.raw_data_table_id
}

output "bigquery_analytics_table" {
  description = "BigQuery table for analytics data"
  value       = module.bigquery.analytics_table_id
}

# Cloud Functions outputs
output "data_ingestion_function_url" {
  description = "URL of the data ingestion Cloud Function"
  value       = module.cloud_functions.ingestion_function_url
}

# Dataproc outputs
output "dataproc_batch_endpoint" {
  description = "Endpoint for submitting Dataproc serverless batches"
  value       = "https://dataproc.googleapis.com/v1/projects/${var.project_id}/locations/${var.region}/batches"
}

# Composer outputs
output "composer_airflow_uri" {
  description = "Airflow web UI URL (if Composer is enabled)"
  value       = var.enable_composer ? module.composer[0].airflow_uri : "Composer not enabled"
}

output "composer_dag_gcs_prefix" {
  description = "GCS prefix for Airflow DAGs (if Composer is enabled)"
  value       = var.enable_composer ? module.composer[0].dag_gcs_prefix : "Composer not enabled"
}

# Quick start commands
output "test_pubsub_publish" {
  description = "Command to test publishing to Pub/Sub"
  value       = "gcloud pubsub topics publish ${module.pubsub.raw_data_topic_id} --message='{\"test\": \"data\"}'"
}

output "submit_dataproc_job_command" {
  description = "Example command to submit a Dataproc serverless job"
  value       = "gcloud dataproc batches submit pyspark gs://${module.storage.staging_bucket_name}/pyspark-jobs/etl_transform.py --region=${var.region} --service-account=${google_service_account.data_pipeline_sa.email}"
}

# Cloud Run UI outputs
output "ui_service_url" {
  description = "URL of the React UI application (if enabled)"
  value       = var.enable_ui ? module.cloud_run[0].service_url : "UI not enabled"
}

output "ui_service_name" {
  description = "Name of the Cloud Run UI service (if enabled)"
  value       = var.enable_ui ? module.cloud_run[0].service_name : "UI not enabled"
}
