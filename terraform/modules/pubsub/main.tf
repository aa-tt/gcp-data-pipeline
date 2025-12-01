# Topic for raw incoming data (like Kafka topic)
resource "google_pubsub_topic" "raw_data" {
  name = "raw-data-topic-${var.environment}"
  
  labels = merge(var.labels, {
    type = "raw-data"
  })

  message_retention_duration = "604800s" # 7 days
}

# Subscription for processing raw data
resource "google_pubsub_subscription" "raw_data_processing" {
  name  = "raw-data-processing-sub-${var.environment}"
  topic = google_pubsub_topic.raw_data.name

  # Acknowledge deadline
  ack_deadline_seconds = 600

  # Retry policy
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  # Dead letter policy for failed messages
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 5
  }

  # Message retention
  message_retention_duration = "604800s" # 7 days
  retain_acked_messages      = false

  expiration_policy {
    ttl = "" # Never expire
  }

  labels = var.labels
}

# Topic for processed/transformed data
resource "google_pubsub_topic" "processed_data" {
  name = "processed-data-topic-${var.environment}"
  
  labels = merge(var.labels, {
    type = "processed-data"
  })

  message_retention_duration = "86400s" # 1 day
}

# Subscription for downstream consumers
resource "google_pubsub_subscription" "processed_data_consumer" {
  name  = "processed-data-consumer-sub-${var.environment}"
  topic = google_pubsub_topic.processed_data.name

  ack_deadline_seconds = 300

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "300s"
  }

  message_retention_duration = "86400s" # 1 day
  retain_acked_messages      = false

  labels = var.labels
}

# Dead letter topic for failed messages
resource "google_pubsub_topic" "dead_letter" {
  name = "dead-letter-topic-${var.environment}"
  
  labels = merge(var.labels, {
    type = "dead-letter"
  })

  message_retention_duration = "2592000s" # 30 days
}

# Subscription for monitoring dead letters
resource "google_pubsub_subscription" "dead_letter_monitor" {
  name  = "dead-letter-monitor-sub-${var.environment}"
  topic = google_pubsub_topic.dead_letter.name

  ack_deadline_seconds       = 600
  message_retention_duration = "2592000s" # 30 days

  labels = var.labels
}

# Topic for triggering batch jobs
resource "google_pubsub_topic" "batch_trigger" {
  name = "batch-trigger-topic-${var.environment}"
  
  labels = merge(var.labels, {
    type = "batch-trigger"
  })
}

# IAM: Allow service account to publish and subscribe
resource "google_pubsub_topic_iam_member" "raw_data_publisher" {
  topic  = google_pubsub_topic.raw_data.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${var.service_account}"
}

resource "google_pubsub_subscription_iam_member" "raw_data_subscriber" {
  subscription = google_pubsub_subscription.raw_data_processing.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${var.service_account}"
}
