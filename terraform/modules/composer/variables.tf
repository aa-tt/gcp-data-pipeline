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

variable "node_count" {
  description = "Number of Composer nodes"
  type        = number
}

variable "machine_type" {
  description = "Machine type for Composer nodes"
  type        = string
}
