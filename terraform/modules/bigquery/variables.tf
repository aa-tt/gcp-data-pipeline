variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "dataset_location" {
  description = "BigQuery dataset location"
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
