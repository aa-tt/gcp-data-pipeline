output "ingestion_function_name" {
  description = "Name of the data ingestion function"
  value       = google_cloudfunctions2_function.data_ingestion.name
}

output "ingestion_function_url" {
  description = "URL of the data ingestion function"
  value       = google_cloudfunctions2_function.data_ingestion.service_config[0].uri
}

output "processor_function_name" {
  description = "Name of the Pub/Sub processor function"
  value       = google_cloudfunctions2_function.pubsub_processor.name
}

output "function_source_bucket" {
  description = "Bucket containing function source code"
  value       = google_storage_bucket.function_source.name
}

output "analytics_query_function_name" {
  description = "Name of the analytics query function"
  value       = google_cloudfunctions2_function.analytics_query.name
}

output "analytics_query_function_url" {
  description = "URL of the analytics query function"
  value       = google_cloudfunctions2_function.analytics_query.service_config[0].uri
}
