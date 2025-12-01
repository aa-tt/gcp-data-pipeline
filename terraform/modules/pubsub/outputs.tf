output "raw_data_topic_id" {
  description = "ID of the raw data topic"
  value       = google_pubsub_topic.raw_data.id
}

output "raw_data_topic_name" {
  description = "Name of the raw data topic"
  value       = google_pubsub_topic.raw_data.name
}

output "processed_data_topic_id" {
  description = "ID of the processed data topic"
  value       = google_pubsub_topic.processed_data.id
}

output "processed_data_topic_name" {
  description = "Name of the processed data topic"
  value       = google_pubsub_topic.processed_data.name
}

output "dead_letter_topic_id" {
  description = "ID of the dead letter topic"
  value       = google_pubsub_topic.dead_letter.id
}

output "batch_trigger_topic_id" {
  description = "ID of the batch trigger topic"
  value       = google_pubsub_topic.batch_trigger.id
}
