output "instance_name" {
  description = "Name of the Spanner instance"
  value       = google_spanner_instance.main.name
}

output "instance_id" {
  description = "Full instance ID"
  value       = google_spanner_instance.main.id
}

output "database_name" {
  description = "Name of the transactions database"
  value       = google_spanner_database.transactions.name
}

output "database_id" {
  description = "Full database ID"
  value       = google_spanner_database.transactions.id
}

output "instance_config" {
  description = "Spanner instance configuration"
  value       = google_spanner_instance.main.config
}

output "node_count" {
  description = "Number of Spanner nodes"
  value       = google_spanner_instance.main.num_nodes
}

output "connection_string" {
  description = "Connection string for applications"
  value       = "projects/${var.project_id}/instances/${google_spanner_instance.main.name}/databases/${google_spanner_database.transactions.name}"
}

output "instance_state" {
  description = "Current state of the Spanner instance"
  value       = google_spanner_instance.main.state
}
