variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "spanner_instance_config" {
  description = "Spanner instance configuration (regional or multi-region)"
  type        = string
  default     = "regional-us-central1"
  # Options:
  # - regional-us-central1 (single region)
  # - nam3 (US multi-region: Iowa, South Carolina, Northern Virginia)
  # - nam6 (US multi-region: Iowa, South Carolina, Oregon, Los Angeles)
}

variable "spanner_node_count" {
  description = "Number of Spanner nodes (1 node = 2TB storage, 10K QPS)"
  type        = number
  default     = 1
}

variable "enable_deletion_protection" {
  description = "Prevent accidental deletion of Spanner instance"
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}
