variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "labels" {
  description = "Resource labels"
  type        = map(string)
}

variable "service_account" {
  description = "Service account email"
  type        = string
}

variable "pubsub_topic" {
  description = "Pub/Sub topic ID"
  type        = string
}

variable "processed_bucket" {
  description = "Processed data bucket name"
  type        = string
}
