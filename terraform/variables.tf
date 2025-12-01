variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "data_bucket_lifecycle_days" {
  description = "Number of days before data is moved to coldline storage"
  type        = number
  default     = 30
}

variable "dataproc_min_instances" {
  description = "Minimum number of Dataproc worker instances"
  type        = number
  default     = 2
}

variable "dataproc_max_instances" {
  description = "Maximum number of Dataproc worker instances"
  type        = number
  default     = 10
}

variable "bigquery_dataset_location" {
  description = "BigQuery dataset location"
  type        = string
  default     = "US"
}

variable "composer_node_count" {
  description = "Number of Cloud Composer nodes"
  type        = number
  default     = 3
}

variable "composer_machine_type" {
  description = "Machine type for Cloud Composer nodes"
  type        = string
  default     = "n1-standard-1"
}

variable "enable_composer" {
  description = "Enable Cloud Composer (can be expensive, set to false to skip)"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default = {
    managed_by = "terraform"
    project    = "data-pipeline"
  }
}
