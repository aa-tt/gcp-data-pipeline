output "service_url" {
  description = "URL of the deployed Cloud Run service"
  value       = google_cloud_run_service.ui.status[0].url
}

output "service_name" {
  description = "Name of the Cloud Run service"
  value       = google_cloud_run_service.ui.name
}

output "service_location" {
  description = "Location of the Cloud Run service"
  value       = google_cloud_run_service.ui.location
}
