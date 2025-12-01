# Raw data bucket - receives incoming data
resource "google_storage_bucket" "raw_data" {
  name          = "${var.project_id}-raw-data-${var.environment}"
  location      = var.region
  force_destroy = true
  
  uniform_bucket_level_access = true
  
  labels = merge(var.labels, {
    type = "raw-data"
  })

  lifecycle_rule {
    condition {
      age = var.lifecycle_days
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = var.lifecycle_days * 3
    }
    action {
      type = "Delete"
    }
  }

  versioning {
    enabled = true
  }
}

# Processed data bucket - stores transformed data
resource "google_storage_bucket" "processed_data" {
  name          = "${var.project_id}-processed-data-${var.environment}"
  location      = var.region
  force_destroy = true
  
  uniform_bucket_level_access = true
  
  labels = merge(var.labels, {
    type = "processed-data"
  })

  lifecycle_rule {
    condition {
      age = var.lifecycle_days * 2
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  versioning {
    enabled = true
  }
}

# Staging bucket - for temporary files, PySpark jobs, etc.
resource "google_storage_bucket" "staging" {
  name          = "${var.project_id}-staging-${var.environment}"
  location      = var.region
  force_destroy = true
  
  uniform_bucket_level_access = true
  
  labels = merge(var.labels, {
    type = "staging"
  })

  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "Delete"
    }
  }
}

# Archive bucket - for long-term storage
resource "google_storage_bucket" "archive" {
  name          = "${var.project_id}-archive-${var.environment}"
  location      = var.region
  force_destroy = true
  
  uniform_bucket_level_access = true
  storage_class = "ARCHIVE"
  
  labels = merge(var.labels, {
    type = "archive"
  })
}

# Create folders for PySpark jobs
resource "google_storage_bucket_object" "pyspark_jobs_folder" {
  name    = "pyspark-jobs/"
  content = "Folder for PySpark job files"
  bucket  = google_storage_bucket.staging.name
}

# Create folders for Cloud Functions
resource "google_storage_bucket_object" "functions_folder" {
  name    = "cloud-functions/"
  content = "Folder for Cloud Function source code"
  bucket  = google_storage_bucket.staging.name
}
