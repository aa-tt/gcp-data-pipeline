output "raw_bucket_name" {
  description = "Name of the raw data bucket"
  value       = google_storage_bucket.raw_data.name
}

output "processed_bucket_name" {
  description = "Name of the processed data bucket"
  value       = google_storage_bucket.processed_data.name
}

output "staging_bucket_name" {
  description = "Name of the staging bucket"
  value       = google_storage_bucket.staging.name
}

output "archive_bucket_name" {
  description = "Name of the archive bucket"
  value       = google_storage_bucket.archive.name
}

output "raw_bucket_url" {
  description = "URL of the raw data bucket"
  value       = "gs://${google_storage_bucket.raw_data.name}"
}

output "processed_bucket_url" {
  description = "URL of the processed data bucket"
  value       = "gs://${google_storage_bucket.processed_data.name}"
}
