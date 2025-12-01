# Dataproc Serverless batch configuration
# Note: Actual batches are submitted via gcloud or API, this creates the base config

# Create a default batch template for PySpark jobs
resource "google_storage_bucket_object" "batch_config_template" {
  name    = "dataproc-config/batch-template.json"
  bucket  = var.staging_bucket
  content = jsonencode({
    runtimeConfig = {
      version = "2.1"
      properties = {
        "spark.executor.memory"    = "4g"
        "spark.executor.cores"     = "2"
        "spark.driver.memory"      = "4g"
        "spark.dynamicAllocation.enabled" = "true"
        "spark.dynamicAllocation.minExecutors" = tostring(var.min_instances)
        "spark.dynamicAllocation.maxExecutors" = tostring(var.max_instances)
      }
    }
    environmentConfig = {
      executionConfig = {
        serviceAccount = var.service_account
        stagingBucket  = var.staging_bucket
      }
      peripheralsConfig = {
        sparkHistoryServerConfig = {
          dataprocCluster = ""
        }
      }
    }
  })
}

# Cloud Scheduler job to trigger batch processing daily
resource "google_cloud_scheduler_job" "daily_etl" {
  name             = "daily-etl-trigger-${var.environment}"
  description      = "Triggers daily ETL batch job"
  schedule         = "0 2 * * *" # 2 AM daily
  time_zone        = "America/New_York"
  attempt_deadline = "320s"
  region           = var.region

  http_target {
    http_method = "POST"
    uri         = "https://dataproc.googleapis.com/v1/projects/${var.project_id}/locations/${var.region}/batches"
    
    headers = {
      "Content-Type" = "application/json"
    }

    body = base64encode(jsonencode({
      pysparkBatch = {
        mainPythonFileUri = "gs://${var.staging_bucket}/pyspark-jobs/etl_transform.py"
        args = [
          "--date", "$${CURRENT_DATE}",
          "--environment", var.environment
        ]
      }
      runtimeConfig = {
        version = "2.1"
        properties = {
          "spark.executor.memory" = "4g"
          "spark.executor.cores"  = "2"
        }
      }
      environmentConfig = {
        executionConfig = {
          serviceAccount = var.service_account
          stagingBucket  = var.staging_bucket
        }
      }
      labels = var.labels
    }))

    oauth_token {
      service_account_email = var.service_account
    }
  }
}

# Optional: Dataproc Metastore for Hive/Spark metadata (replaces Hive metastore)
# Commented out by default as it adds cost (~$0.40/hour = ~$300/month)
# resource "google_dataproc_metastore_service" "default" {
#   service_id = "dataproc-metastore-${var.environment}"
#   location   = var.region
#   
#   tier = "DEVELOPER" # Use ENTERPRISE for production
#
#   hive_metastore_config {
#     version = "3.1.2"
#   }
#
#   labels = var.labels
# }
