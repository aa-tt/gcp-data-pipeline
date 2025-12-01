output "dataset_id" {
  description = "BigQuery dataset ID"
  value       = google_bigquery_dataset.data_warehouse.dataset_id
}

output "dataset_full_id" {
  description = "Full dataset ID with project"
  value       = "${var.project_id}.${google_bigquery_dataset.data_warehouse.dataset_id}"
}

output "raw_data_table_id" {
  description = "Raw data table ID"
  value       = google_bigquery_table.raw_data.table_id
}

output "analytics_table_id" {
  description = "Analytics table ID"
  value       = google_bigquery_table.analytics.table_id
}

output "metrics_table_id" {
  description = "Metrics table ID"
  value       = google_bigquery_table.metrics.table_id
}

output "latest_analytics_view_id" {
  description = "Latest analytics view ID"
  value       = google_bigquery_table.latest_analytics_view.table_id
}
