/**
 * Cloud Spanner Module
 * 
 * Creates a Cloud Spanner instance and database for real-time transaction processing
 * Use case: Transaction deduplication, user session management, real-time counters
 */

# Create Spanner instance
resource "google_spanner_instance" "main" {
  project      = var.project_id
  name         = "data-pipeline-${var.environment}"
  config       = var.spanner_instance_config
  display_name = "Data Pipeline Spanner Instance (${var.environment})"
  
  # Node count determines capacity (1 node = 2TB storage + 10K QPS)
  num_nodes = var.spanner_node_count
  
  # Prevent accidental deletion in production
  force_destroy = !var.enable_deletion_protection
  
  labels = merge(
    var.labels,
    {
      environment = var.environment
      managed_by  = "terraform"
      component   = "spanner"
    }
  )
}

# Create database for transactions
resource "google_spanner_database" "transactions" {
  instance            = google_spanner_instance.main.name
  name                = "transactions-db"
  deletion_protection = var.enable_deletion_protection
  
  # DDL statements to create tables and indexes
  ddl = [
    # Main transactions table with strong consistency
    <<-EOT
      CREATE TABLE transactions (
        transaction_id STRING(36) NOT NULL,
        user_id STRING(50) NOT NULL,
        product_id STRING(50),
        amount NUMERIC NOT NULL,
        quantity INT64,
        status STRING(20) NOT NULL,
        event_name STRING(50),
        created_at TIMESTAMP NOT NULL OPTIONS (allow_commit_timestamp=true),
        updated_at TIMESTAMP NOT NULL OPTIONS (allow_commit_timestamp=true),
        metadata JSON,
        source_system STRING(50),
      ) PRIMARY KEY (transaction_id)
    EOT
    ,
    
    # Index for efficient user queries
    <<-EOT
      CREATE INDEX idx_user_transactions 
      ON transactions(user_id, created_at DESC)
      STORING (status, amount)
    EOT
    ,
    
    # Index for status-based queries
    <<-EOT
      CREATE INDEX idx_status_transactions 
      ON transactions(status, created_at DESC)
    EOT
    ,
    
    # Real-time counters table
    <<-EOT
      CREATE TABLE daily_counters (
        counter_date DATE NOT NULL,
        counter_name STRING(50) NOT NULL,
        dimension STRING(100),
        counter_value INT64 NOT NULL,
        last_updated TIMESTAMP NOT NULL OPTIONS (allow_commit_timestamp=true),
      ) PRIMARY KEY (counter_date, counter_name, dimension)
    EOT
    ,
    
    # User session/profile cache table
    <<-EOT
      CREATE TABLE user_profiles (
        user_id STRING(50) NOT NULL,
        profile_data JSON,
        last_active TIMESTAMP NOT NULL OPTIONS (allow_commit_timestamp=true),
        session_count INT64 NOT NULL,
        total_spend NUMERIC,
      ) PRIMARY KEY (user_id)
    EOT
  ]
}

# IAM binding for Cloud Functions to access Spanner
resource "google_spanner_database_iam_member" "function_user" {
  instance = google_spanner_instance.main.name
  database = google_spanner_database.transactions.name
  role     = "roles/spanner.databaseUser"
  member   = "serviceAccount:data-pipeline-sa-${var.environment}@${var.project_id}.iam.gserviceaccount.com"
}

# Monitoring: Create alert for high CPU usage
resource "google_monitoring_alert_policy" "spanner_high_cpu" {
  project      = var.project_id
  display_name = "Spanner High CPU - ${var.environment}"
  combiner     = "OR"
  
  conditions {
    display_name = "CPU utilization above 65%"
    
    condition_threshold {
      filter          = "resource.type = \"spanner_instance\" AND resource.labels.instance_id = \"${google_spanner_instance.main.name}\" AND metric.type = \"spanner.googleapis.com/instance/cpu/utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.65
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }
  
  notification_channels = []
  
  alert_strategy {
    auto_close = "1800s"
  }
}
