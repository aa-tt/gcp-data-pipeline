output "composer_environment_name" {
  description = "Name of the Composer environment"
  value       = google_composer_environment.data_pipeline.name
}

output "airflow_uri" {
  description = "Airflow web UI URL"
  value       = google_composer_environment.data_pipeline.config[0].airflow_uri
}

output "dag_gcs_prefix" {
  description = "GCS prefix for Airflow DAGs"
  value       = google_composer_environment.data_pipeline.config[0].dag_gcs_prefix
}

output "gke_cluster" {
  description = "GKE cluster running Composer"
  value       = google_composer_environment.data_pipeline.config[0].gke_cluster
}
