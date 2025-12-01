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

variable "min_instances" {
  description = "Minimum worker instances"
  type        = number
}

variable "max_instances" {
  description = "Maximum worker instances"
  type        = number
}

variable "staging_bucket" {
  description = "Staging bucket name"
  type        = string
}
