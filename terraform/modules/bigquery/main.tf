# BigQuery dataset for data warehouse
resource "google_bigquery_dataset" "data_warehouse" {
  dataset_id  = "data_warehouse_${var.environment}"
  project     = var.project_id
  location    = var.dataset_location
  description = "Data warehouse for analytics and reporting"

  labels = var.labels

  # Default table expiration (90 days for temporary tables)
  default_table_expiration_ms = 7776000000

  # Access control
  access {
    role          = "OWNER"
    user_by_email = var.service_account
  }

  access {
    role          = "roles/bigquery.dataEditor"
    user_by_email = var.service_account
  }
}

# Raw data table - stores unprocessed data
resource "google_bigquery_table" "raw_data" {
  dataset_id = google_bigquery_dataset.data_warehouse.dataset_id
  table_id   = "raw_data"
  project    = var.project_id

  description = "Raw data ingested from Pub/Sub"

  labels = var.labels

  # Partitioning by ingestion time for cost optimization
  time_partitioning {
    type          = "DAY"
    field         = "ingestion_timestamp"
    expiration_ms = 15552000000 # 180 days
  }

  # Clustering for query optimization
  clustering = ["source_system", "data_type"]

  schema = jsonencode([
    {
      name        = "id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Unique record identifier"
    },
    {
      name        = "ingestion_timestamp"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "Time when data was ingested"
    },
    {
      name        = "source_system"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Source system identifier"
    },
    {
      name        = "data_type"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Type of data"
    },
    {
      name        = "raw_payload"
      type        = "JSON"
      mode        = "REQUIRED"
      description = "Raw JSON payload"
    },
    {
      name        = "metadata"
      type = "RECORD"
      mode = "NULLABLE"
      description = "Additional metadata"
      fields = [
        {
          name = "version"
          type = "STRING"
          mode = "NULLABLE"
        },
        {
          name = "environment"
          type = "STRING"
          mode = "NULLABLE"
        }
      ]
    }
  ])
}

# Analytics table - stores transformed/aggregated data
resource "google_bigquery_table" "analytics" {
  dataset_id = google_bigquery_dataset.data_warehouse.dataset_id
  table_id   = "analytics_data"
  project    = var.project_id

  description = "Transformed data for analytics"

  labels = var.labels

  # Partitioning by date
  time_partitioning {
    type  = "DAY"
    field = "event_date"
  }

  # Clustering
  clustering = ["category", "region", "product_id"]

  schema = jsonencode([
    {
      name        = "event_date"
      type        = "DATE"
      mode        = "REQUIRED"
      description = "Event date"
    },
    {
      name        = "event_timestamp"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "Event timestamp"
    },
    {
      name        = "user_id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "User identifier"
    },
    {
      name        = "product_id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Product identifier"
    },
    {
      name        = "category"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Event category"
    },
    {
      name        = "region"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Geographic region"
    },
    {
      name        = "amount"
      type        = "NUMERIC"
      mode        = "NULLABLE"
      description = "Transaction amount"
    },
    {
      name        = "quantity"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Quantity"
    },
    {
      name        = "attributes"
      type        = "JSON"
      mode        = "NULLABLE"
      description = "Additional attributes"
    }
  ])
}

# Aggregated metrics table
resource "google_bigquery_table" "metrics" {
  dataset_id = google_bigquery_dataset.data_warehouse.dataset_id
  table_id   = "daily_metrics"
  project    = var.project_id

  description = "Daily aggregated metrics"

  labels = var.labels

  time_partitioning {
    type  = "DAY"
    field = "metric_date"
  }

  schema = jsonencode([
    {
      name        = "metric_date"
      type        = "DATE"
      mode        = "REQUIRED"
      description = "Metric date"
    },
    {
      name        = "metric_name"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Metric name"
    },
    {
      name        = "dimension"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Metric dimension"
    },
    {
      name        = "value"
      type        = "NUMERIC"
      mode        = "REQUIRED"
      description = "Metric value"
    },
    {
      name        = "count"
      type        = "INTEGER"
      mode        = "REQUIRED"
      description = "Count of events"
    }
  ])
}

# View for latest data
resource "google_bigquery_table" "latest_analytics_view" {
  dataset_id = google_bigquery_dataset.data_warehouse.dataset_id
  table_id   = "latest_analytics_view"
  project    = var.project_id

  description = "View showing latest analytics data"

  labels = var.labels

  view {
    query = <<-SQL
      SELECT
        *
      FROM
        `${var.project_id}.${google_bigquery_dataset.data_warehouse.dataset_id}.${google_bigquery_table.analytics.table_id}`
      WHERE
        event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
    SQL

    use_legacy_sql = false
  }
}
