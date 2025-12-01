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

variable "lifecycle_days" {
  description = "Days before moving to coldline storage"
  type        = number
}

variable "labels" {
  description = "Resource labels"
  type        = map(string)
}

variable "service_account" {
  description = "Service account email"
  type        = string
}
