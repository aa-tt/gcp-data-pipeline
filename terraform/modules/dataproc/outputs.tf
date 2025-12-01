output "batch_config_path" {
  description = "Path to batch configuration template"
  value       = "gs://${var.staging_bucket}/${google_storage_bucket_object.batch_config_template.name}"
}

output "scheduler_job_name" {
  description = "Name of the Cloud Scheduler job"
  value       = google_cloud_scheduler_job.daily_etl.name
}

output "submit_batch_command" {
  description = "Example command to submit a Dataproc batch"
  value       = "gcloud dataproc batches submit pyspark gs://${var.staging_bucket}/pyspark-jobs/etl_transform.py --region=${var.region} --service-account=${var.service_account}"
}
