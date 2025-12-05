# Snowflake Integration Guide

This guide explains how to replace BigQuery with Snowflake as the data warehouse in the GCP data pipeline.

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Integration Methods](#integration-methods)
- [Batch vs Individual Processing](#batch-vs-individual-processing)
- [Error Handling & Reprocessing](#error-handling--reprocessing)
- [Implementation Guide](#implementation-guide)
- [Best Practices](#best-practices)

---

## Architecture Overview

### Current Architecture (BigQuery)
```
Cloud Function → Pub/Sub → GCS → Dataproc (PySpark) → BigQuery
```

### Modified Architecture (Snowflake)
```
Cloud Function → Pub/Sub → GCS → Dataproc (PySpark) → Snowflake
                                  ↓
                            Snowflake External Stage
```

### Remove BigQuery?
**Yes!** Snowflake can completely replace BigQuery as the data warehouse. Optionally keep BigQuery for:
- Cost tracking and billing analysis
- Error logging and monitoring
- GCP-native analytics dashboards

---

## Integration Methods

### Option A: Snowflake Spark Connector (Recommended)

**Best for:** Batch processing with PySpark, direct DataFrame writes

**How it works:**
- Uses JDBC/ODBC under the hood
- Automatically stages data in Snowflake internal stage
- Uses Snowflake's COPY command for bulk loading
- **Batch mode by default**

**Example Implementation:**

```python
# pyspark-jobs/etl_transform_snowflake.py
from pyspark.sql import SparkSession
from pyspark.sql.functions import *

spark = SparkSession.builder \
    .appName("ETL-Snowflake") \
    .config("spark.jars.packages", "net.snowflake:spark-snowflake_2.12:2.12.0-spark_3.3") \
    .getOrCreate()

# Snowflake connection options
sfOptions = {
    "sfURL": "your-account.snowflakecomputing.com",
    "sfUser": "pipeline_user",
    "sfPassword": "***",  # Use Secret Manager in production
    "sfDatabase": "DATA_WAREHOUSE",
    "sfSchema": "PRODUCTION",
    "sfWarehouse": "COMPUTE_WH",
    "sfRole": "DATA_ENGINEER"
}

# Read from GCS
bucket = "datapipeline-480007-processed-data-dev"
analytics_df = spark.read.json(f"gs://{bucket}/processed/**/*.json")

# Transform data
transformed_df = analytics_df.select(
    col("data.user_id").alias("user_id"),
    col("data.product_id").alias("product_id"),
    col("data.amount").alias("amount"),
    to_date(col("ingestion_timestamp")).alias("event_date")
)

# WRITE TO SNOWFLAKE
transformed_df.write \
    .format("snowflake") \
    .options(**sfOptions) \
    .option("dbtable", "analytics_data") \
    .option("truncate_table", "off") \
    .option("usestagingtable", "on") \
    .mode("append") \
    .save()
```

**Pros:**
- Simple PySpark API
- Good for moderate data volumes
- Automatic staging and cleanup

**Cons:**
- Slower than COPY INTO for very large datasets
- Less control over loading process

---

### Option B: GCS External Stage + COPY INTO (Most Efficient)

**Best for:** Large batch loads, cost optimization, maximum control

**Step 1: PySpark writes to GCS as Parquet**

```python
# Write intermediate Parquet files
analytics_df.write \
    .mode("overwrite") \
    .partitionBy("event_date") \
    .parquet(f"gs://{bucket}/snowflake-staging/{date}/analytics/")

metrics_df.write \
    .mode("overwrite") \
    .partitionBy("metric_date") \
    .parquet(f"gs://{bucket}/snowflake-staging/{date}/metrics/")
```

**Step 2: Snowflake setup (one-time)**

```sql
-- Create storage integration for GCP
CREATE STORAGE INTEGRATION gcp_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = GCS
  ENABLED = TRUE
  STORAGE_ALLOWED_LOCATIONS = ('gcs://datapipeline-480007-processed-data-dev/snowflake-staging/');

-- Get service account for GCS permissions
DESC STORAGE INTEGRATION gcp_integration;
-- Grant Storage Object Viewer role to the service account in GCP

-- Create external stage pointing to GCS
CREATE OR REPLACE STAGE gcs_stage
  URL = 'gcs://datapipeline-480007-processed-data-dev/snowflake-staging/'
  STORAGE_INTEGRATION = gcp_integration;

-- Create file format
CREATE OR REPLACE FILE FORMAT parquet_format
  TYPE = PARQUET
  COMPRESSION = AUTO;

-- Verify stage access
LIST @gcs_stage;
```

**Step 3: Load data using COPY INTO**

```sql
-- COPY data into Snowflake table (BATCH MODE)
COPY INTO analytics_data
FROM @gcs_stage/2025-12-03/analytics/
FILE_FORMAT = (FORMAT_NAME = parquet_format)
PATTERN = '.*[.]parquet'
ON_ERROR = 'CONTINUE'
PURGE = TRUE;  -- Delete files after successful load

-- Check load history
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'ANALYTICS_DATA',
    START_TIME => DATEADD(hours, -24, CURRENT_TIMESTAMP())
));
```

**Step 4: Automate with Python/Cloud Function**

```python
import snowflake.connector
from google.cloud import secretmanager

def get_snowflake_password():
    client = secretmanager.SecretManagerServiceClient()
    name = "projects/datapipeline-480007/secrets/snowflake-password/versions/latest"
    response = client.access_secret_version(request={"name": name})
    return response.payload.data.decode("UTF-8")

def load_to_snowflake(date):
    """Execute COPY INTO command from Python"""
    
    conn = snowflake.connector.connect(
        user='pipeline_user',
        password=get_snowflake_password(),
        account='your-account',
        warehouse='COMPUTE_WH',
        database='DATA_WAREHOUSE',
        schema='PRODUCTION'
    )
    
    cursor = conn.cursor()
    
    try:
        # Load analytics data
        copy_sql = f"""
        COPY INTO analytics_data
        FROM @gcs_stage/{date}/analytics/
        FILE_FORMAT = (FORMAT_NAME = parquet_format)
        PATTERN = '.*[.]parquet'
        ON_ERROR = 'CONTINUE'
        RETURN_FAILED_ONLY = TRUE
        PURGE = TRUE
        """
        
        cursor.execute(copy_sql)
        results = cursor.fetchall()
        
        # Check for errors
        failed_count = len([r for r in results if r[1] == 'LOAD_FAILED'])
        
        if failed_count > 0:
            print(f"Warning: {failed_count} files failed to load")
            return {"status": "partial_success", "failed": failed_count}
        
        print(f"Successfully loaded data for {date}")
        return {"status": "success"}
        
    except Exception as e:
        print(f"Error loading to Snowflake: {str(e)}")
        raise
    finally:
        cursor.close()
        conn.close()
```

**Pros:**
- **Fastest** loading method for large datasets
- Full control over error handling
- Can use VALIDATION_MODE to test before loading
- Supports partition pruning

**Cons:**
- Requires more setup (storage integration)
- Two-step process (write Parquet, then COPY)

---

### Option C: Snowpipe (Auto-Ingest Streaming)

**Best for:** Near real-time, continuous loading, event-driven architecture

**Setup:**

```sql
-- Create Snowpipe for auto-ingest
CREATE OR REPLACE PIPE analytics_pipe
  AUTO_INGEST = TRUE
  AS
  COPY INTO analytics_data
  FROM @gcs_stage/
  FILE_FORMAT = (FORMAT_NAME = parquet_format)
  PATTERN = '.*/analytics/.*[.]parquet'
  ON_ERROR = 'CONTINUE';

-- Get notification channel
SHOW PIPES;
-- Note the notification_channel value for GCS Pub/Sub
```

**GCS Pub/Sub Notification (Terraform):**

```hcl
# terraform/modules/snowflake-integration/main.tf
resource "google_pubsub_topic" "snowpipe_notification" {
  name    = "snowpipe-notification-${var.environment}"
  project = var.project_id
}

resource "google_storage_notification" "snowpipe_trigger" {
  bucket         = var.staging_bucket
  payload_format = "JSON_API_V1"
  topic          = google_pubsub_topic.snowpipe_notification.id
  event_types    = ["OBJECT_FINALIZE"]
  
  object_name_prefix = "snowflake-staging/"
  
  custom_attributes = {
    pipe = "analytics_pipe"
  }
}
```

**Pros:**
- Automatic, near real-time loading
- Serverless (no compute management)
- Cost-effective for streaming

**Cons:**
- Small files can be inefficient
- Less control over load timing
- Additional GCP Pub/Sub costs

---

## Batch vs Individual Processing

### Communication Modes

| Method | Mode | Records/Call | Performance | Use Case |
|--------|------|--------------|-------------|----------|
| **Spark Connector** | Batch (DataFrame) | Thousands-Millions | ⭐⭐⭐⭐ Good | Standard ETL |
| **COPY INTO** | Batch (Files) | Millions+ | ⭐⭐⭐⭐⭐ Best | Large datasets |
| **Snowpipe** | Micro-batch (Files) | Per file | ⭐⭐⭐⭐ Good | Streaming |
| **INSERT statements** | Row-by-row | 1 | ⭐ Poor | **AVOID** |

### Recommended: Batch Mode

```python
# ✅ GOOD: Batch processing (thousands of records at once)
analytics_df.write \
    .format("snowflake") \
    .options(**sfOptions) \
    .option("dbtable", "analytics_data") \
    .mode("append") \
    .save()

# ❌ BAD: Row-by-row (very slow, expensive)
for row in data:
    cursor.execute("INSERT INTO analytics_data VALUES (%s, %s, %s)", row)
```

**Batch Sizes in Our Pipeline:**
```
- Frequency: Daily batch jobs
- Typical size: 100-1000 files per day
- Records per batch: Thousands to millions
- Processing time: 2-10 minutes depending on volume
```

---

## Error Handling & Reprocessing

### 1. ON_ERROR Options

Snowflake provides several error handling strategies:

```sql
-- Option 1: Continue on error (RECOMMENDED for large batches)
COPY INTO analytics_data
FROM @gcs_stage/2025-12-03/
ON_ERROR = 'CONTINUE'  -- Skip bad rows, continue loading
RETURN_FAILED_ONLY = TRUE;  -- Only return failed records

-- Option 2: Skip file on error
COPY INTO analytics_data
FROM @gcs_stage/2025-12-03/
ON_ERROR = 'SKIP_FILE';  -- Skip entire file if any error

-- Option 3: Abort on error (safest but fails entire batch)
COPY INTO analytics_data
FROM @gcs_stage/2025-12-03/
ON_ERROR = 'ABORT_STATEMENT';  -- Fail entire load on first error

-- Option 4: Skip file after N errors
COPY INTO analytics_data
FROM @gcs_stage/2025-12-03/
ON_ERROR = 'SKIP_FILE_3';  -- Skip file after 3 errors
```

### 2. Error Tracking

**Query Load History:**

```sql
-- Check recent load results
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'ANALYTICS_DATA',
    START_TIME => DATEADD(hours, -24, CURRENT_TIMESTAMP())
))
WHERE STATUS = 'FAILED' OR ERROR_COUNT > 0
ORDER BY LAST_LOAD_TIME DESC;

-- Get detailed error information
SELECT 
    file_name,
    row_number,
    error_message,
    rejected_record
FROM TABLE(VALIDATE(analytics_data, JOB_ID => '_last'));
```

**Create Error Logging Table:**

```sql
CREATE TABLE load_errors (
    error_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    table_name STRING,
    batch_id STRING,
    file_name STRING,
    row_number NUMBER,
    error_message STRING,
    rejected_record VARIANT
);

-- Log errors from failed loads
INSERT INTO load_errors
SELECT 
    CURRENT_TIMESTAMP(),
    'analytics_data',
    '20251203-batch-001',
    file_name,
    row_number,
    error_message,
    rejected_record
FROM TABLE(VALIDATE(analytics_data, JOB_ID => '_last'))
WHERE error_message IS NOT NULL;
```

### 3. Idempotent Reprocessing

**Safe retry mechanism:**

```python
def load_to_snowflake_with_retry(date, max_retries=3):
    """Idempotent load with automatic retry logic"""
    
    conn = snowflake.connector.connect(**connection_params)
    cursor = conn.cursor()
    
    # Check if already loaded
    check_sql = f"""
    SELECT COUNT(*) as loaded_count
    FROM analytics_data
    WHERE event_date = '{date}'
    """
    
    cursor.execute(check_sql)
    loaded_count = cursor.fetchone()[0]
    
    if loaded_count > 0:
        print(f"Date {date} already loaded ({loaded_count} records)")
        print("Deleting existing data for reprocessing...")
        
        # Delete existing partition (idempotent)
        delete_sql = f"DELETE FROM analytics_data WHERE event_date = '{date}'"
        cursor.execute(delete_sql)
    
    # Attempt load with exponential backoff
    for attempt in range(max_retries):
        try:
            copy_sql = f"""
            COPY INTO analytics_data
            FROM @gcs_stage/{date}/analytics/
            FILE_FORMAT = (FORMAT_NAME = parquet_format)
            ON_ERROR = 'CONTINUE'
            FORCE = TRUE
            """
            
            cursor.execute(copy_sql)
            results = cursor.fetchall()
            
            # Evaluate results
            total_files = len(results)
            failed_files = sum(1 for r in results if r[1] == 'LOAD_FAILED')
            error_rate = failed_files / total_files if total_files > 0 else 0
            
            if error_rate == 0:
                print(f"✅ Successfully loaded {date} - all files succeeded")
                return {"status": "success", "files": total_files}
            
            elif error_rate < 0.05:  # Less than 5% errors acceptable
                print(f"⚠️  Loaded {date} with {failed_files}/{total_files} failures")
                log_errors_to_table(cursor, results, date)
                return {"status": "partial_success", "failed": failed_files}
            
            else:
                raise Exception(f"Too many errors: {failed_files}/{total_files} files failed")
                
        except Exception as e:
            print(f"❌ Attempt {attempt + 1}/{max_retries} failed: {str(e)}")
            
            if attempt < max_retries - 1:
                wait_time = 60 * (2 ** attempt)  # Exponential backoff
                print(f"Retrying in {wait_time} seconds...")
                time.sleep(wait_time)
            else:
                # Final attempt failed - quarantine batch
                print(f"All retries exhausted. Quarantining batch for {date}")
                quarantine_failed_batch(date, str(e))
                raise
    
    cursor.close()
    conn.close()
```

### 4. Dead Letter Queue Pattern

**Move failed batches to quarantine:**

```python
def quarantine_failed_batch(date, error_message):
    """Move failed batch files to quarantine bucket for investigation"""
    
    source_path = f"gs://{bucket}/snowflake-staging/{date}/"
    quarantine_path = f"gs://{bucket}/quarantine/snowflake/{date}/"
    
    # Copy files to quarantine
    import subprocess
    subprocess.run([
        "gsutil", "-m", "cp", "-r", 
        source_path, 
        quarantine_path
    ])
    
    # Log failure details to BigQuery (optional - for monitoring)
    from google.cloud import bigquery
    client = bigquery.Client()
    
    rows_to_insert = [{
        "failure_timestamp": datetime.now().isoformat(),
        "batch_date": date,
        "error_message": error_message,
        "quarantine_path": quarantine_path,
        "status": "quarantined"
    }]
    
    errors = client.insert_rows_json(
        "datapipeline-480007.monitoring.load_failures", 
        rows_to_insert
    )
    
    # Send alert
    send_slack_alert(
        f"🚨 Snowflake load failed for {date}\n"
        f"Error: {error_message}\n"
        f"Files moved to: {quarantine_path}"
    )
```

### 5. Checkpoint-Based Processing

**Track individual file processing:**

```sql
-- Create checkpoint table
CREATE TABLE load_checkpoints (
    batch_id STRING,
    batch_date DATE,
    file_path STRING,
    file_size NUMBER,
    status STRING,  -- 'PENDING', 'LOADED', 'FAILED'
    error_message STRING,
    attempt_count NUMBER DEFAULT 0,
    first_attempt_timestamp TIMESTAMP_NTZ,
    loaded_timestamp TIMESTAMP_NTZ,
    rows_loaded NUMBER
);

-- Initialize checkpoint entries
INSERT INTO load_checkpoints (batch_id, batch_date, file_path, status)
SELECT 
    '20251203-batch-001',
    '2025-12-03',
    metadata$filename,
    'PENDING'
FROM @gcs_stage/2025-12-03/
WHERE metadata$filename NOT IN (
    SELECT file_path FROM load_checkpoints WHERE status = 'LOADED'
);

-- Load only unprocessed files
COPY INTO analytics_data
FROM (
    SELECT $1, $2, $3, $4 
    FROM @gcs_stage/2025-12-03/
    WHERE metadata$filename NOT IN (
        SELECT file_path 
        FROM load_checkpoints 
        WHERE status = 'LOADED'
    )
)
FILE_FORMAT = (FORMAT_NAME = parquet_format)
ON_ERROR = 'CONTINUE';

-- Update successful loads
MERGE INTO load_checkpoints AS target
USING (
    SELECT 
        metadata$filename as file_path,
        COUNT(*) as rows_count
    FROM @gcs_stage/2025-12-03/
    GROUP BY metadata$filename
) AS source
ON target.file_path = source.file_path
WHEN MATCHED THEN UPDATE SET
    status = 'LOADED',
    loaded_timestamp = CURRENT_TIMESTAMP(),
    rows_loaded = source.rows_count;
```

### 6. Validation Before Loading

**Test data quality before committing:**

```sql
-- Dry run - validate without loading
COPY INTO analytics_data
FROM @gcs_stage/2025-12-03/
VALIDATION_MODE = 'RETURN_ERRORS'
FILE_FORMAT = (FORMAT_NAME = parquet_format);

-- Returns any errors without loading data
-- Use this to catch issues before actual load

-- Validate specific number of rows
COPY INTO analytics_data
FROM @gcs_stage/2025-12-03/
VALIDATION_MODE = 'RETURN_10_ROWS'
FILE_FORMAT = (FORMAT_NAME = parquet_format);
```

---

## Implementation Guide

### Complete Modified PySpark ETL Job

```python
# pyspark-jobs/etl_transform_snowflake.py
import argparse
import os
import time
from datetime import datetime
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from google.cloud import secretmanager
import snowflake.connector

def get_secret(project_id, secret_id):
    """Retrieve secret from Secret Manager"""
    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{project_id}/secrets/{secret_id}/versions/latest"
    response = client.access_secret_version(request={"name": name})
    return response.payload.data.decode("UTF-8")

def get_snowflake_options(project_id, environment):
    """Build Snowflake connection options"""
    return {
        "sfURL": os.getenv("SNOWFLAKE_ACCOUNT", "your-account.snowflakecomputing.com"),
        "sfUser": os.getenv("SNOWFLAKE_USER", "pipeline_user"),
        "sfPassword": get_secret(project_id, "snowflake-password"),
        "sfDatabase": "DATA_WAREHOUSE",
        "sfSchema": environment.upper(),
        "sfWarehouse": "COMPUTE_WH",
        "sfRole": "DATA_ENGINEER"
    }

def transform_analytics_data(df):
    """Transform raw JSON to analytics schema"""
    return df.select(
        to_date(col("ingestion_timestamp")).alias("event_date"),
        to_timestamp(col("ingestion_timestamp")).alias("event_timestamp"),
        col("data.user_id").alias("user_id"),
        col("data.product_id").alias("product_id"),
        col("data.transaction_id").alias("transaction_id"),
        col("data.category").alias("category"),
        col("data.region").alias("region"),
        col("data.amount").cast("float").alias("amount"),
        col("data.quantity").cast("int").alias("quantity"),
        to_json(struct(
            col("source_system"),
            col("data_type")
        )).alias("attributes")
    )

def calculate_metrics(df):
    """Calculate daily metrics"""
    return df.groupBy("event_date") \
        .agg(
            lit("total_amount").alias("metric_name"),
            lit(None).cast("string").alias("dimension"),
            sum("amount").alias("value"),
            count("*").alias("count")
        ) \
        .withColumnRenamed("event_date", "metric_date")

def load_via_spark_connector(df, table_name, sf_options):
    """Load data using Snowflake Spark Connector"""
    df.write \
        .format("snowflake") \
        .options(**sf_options) \
        .option("dbtable", table_name) \
        .option("truncate_table", "off") \
        .option("usestagingtable", "on") \
        .mode("append") \
        .save()

def load_via_copy_into(df, date, bucket, project_id, sf_options):
    """Load data using COPY INTO (two-step process)"""
    
    # Step 1: Write to GCS as Parquet
    staging_path = f"gs://{bucket}/snowflake-staging/{date}/analytics/"
    df.write \
        .mode("overwrite") \
        .partitionBy("event_date") \
        .parquet(staging_path)
    
    print(f"Wrote Parquet files to {staging_path}")
    
    # Step 2: Execute COPY INTO
    conn = snowflake.connector.connect(
        user=sf_options["sfUser"],
        password=sf_options["sfPassword"],
        account=sf_options["sfURL"].replace(".snowflakecomputing.com", ""),
        warehouse=sf_options["sfWarehouse"],
        database=sf_options["sfDatabase"],
        schema=sf_options["sfSchema"]
    )
    
    cursor = conn.cursor()
    
    try:
        copy_sql = f"""
        COPY INTO analytics_data
        FROM @gcs_stage/{date}/analytics/
        FILE_FORMAT = (FORMAT_NAME = parquet_format)
        PATTERN = '.*[.]parquet'
        ON_ERROR = 'CONTINUE'
        RETURN_FAILED_ONLY = TRUE
        PURGE = TRUE
        """
        
        cursor.execute(copy_sql)
        results = cursor.fetchall()
        
        success_count = sum(1 for r in results if r[1] == 'LOADED')
        failed_count = sum(1 for r in results if r[1] == 'LOAD_FAILED')
        
        print(f"Load complete: {success_count} files succeeded, {failed_count} files failed")
        
        if failed_count > 0:
            print("Failed files:")
            for row in results:
                if row[1] == 'LOAD_FAILED':
                    print(f"  - {row[0]}: {row[2]}")
        
        return {"success": success_count, "failed": failed_count}
        
    finally:
        cursor.close()
        conn.close()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-id", required=True, help="GCP Project ID")
    parser.add_argument("--environment", required=True, help="Environment (dev/prod)")
    parser.add_argument("--date", required=True, help="Date to process (YYYY-MM-DD)")
    parser.add_argument("--method", default="connector", choices=["connector", "copy"],
                       help="Load method: connector (Spark) or copy (COPY INTO)")
    args = parser.parse_args()
    
    # Initialize Spark
    spark_builder = SparkSession.builder \
        .appName(f"ETL-Snowflake-{args.environment}")
    
    if args.method == "connector":
        spark_builder = spark_builder.config(
            "spark.jars.packages", 
            "net.snowflake:spark-snowflake_2.12:2.12.0-spark_3.3"
        )
    
    spark = spark_builder.getOrCreate()
    
    # Configuration
    bucket = f"{args.project_id}-processed-data-{args.environment}"
    sf_options = get_snowflake_options(args.project_id, args.environment)
    
    print(f"Processing data for {args.date}")
    print(f"Method: {args.method}")
    
    # Read data from GCS
    input_path = f"gs://{bucket}/processed/**/{args.date}/*.json"
    print(f"Reading from: {input_path}")
    
    raw_df = spark.read.json(input_path)
    record_count = raw_df.count()
    print(f"Found {record_count} records")
    
    if record_count == 0:
        print("No data to process. Exiting.")
        return
    
    # Transform data
    print("Transforming analytics data...")
    analytics_df = transform_analytics_data(raw_df)
    
    print("Calculating metrics...")
    metrics_df = calculate_metrics(analytics_df)
    
    # Load data based on method
    try:
        if args.method == "connector":
            print("Loading via Snowflake Spark Connector...")
            load_via_spark_connector(analytics_df, "analytics_data", sf_options)
            load_via_spark_connector(metrics_df, "daily_metrics", sf_options)
            print("✅ Data loaded successfully via Spark Connector")
            
        else:  # copy method
            print("Loading via COPY INTO...")
            result = load_via_copy_into(analytics_df, args.date, bucket, 
                                       args.project_id, sf_options)
            
            if result["failed"] > 0:
                print(f"⚠️  Loaded with {result['failed']} failures")
            else:
                print("✅ Data loaded successfully via COPY INTO")
    
    except Exception as e:
        print(f"❌ Error loading data: {str(e)}")
        
        # Fallback: Save to quarantine
        quarantine_path = f"gs://{bucket}/quarantine/snowflake/{args.date}/"
        print(f"Saving data to quarantine: {quarantine_path}")
        
        analytics_df.write.mode("overwrite").parquet(f"{quarantine_path}/analytics/")
        metrics_df.write.mode("overwrite").parquet(f"{quarantine_path}/metrics/")
        
        raise
    
    finally:
        spark.stop()

if __name__ == "__main__":
    main()
```

### Terraform Module for Snowflake Integration

```hcl
# terraform/modules/snowflake-integration/main.tf

# Secret for Snowflake password
resource "google_secret_manager_secret" "snowflake_password" {
  secret_id = "snowflake-password"
  project   = var.project_id

  replication {
    auto {}
  }
}

# GCS bucket for Snowflake staging
resource "google_storage_bucket" "snowflake_staging" {
  name          = "${var.project_id}-snowflake-staging-${var.environment}"
  location      = var.region
  force_destroy = true
  
  uniform_bucket_level_access = true
  
  lifecycle_rule {
    condition {
      age = 7  # Delete staging files after 7 days
    }
    action {
      type = "Delete"
    }
  }
}

# Service account for Snowflake access
resource "google_service_account" "snowflake_loader" {
  account_id   = "snowflake-loader-${var.environment}"
  display_name = "Snowflake Data Loader"
  project      = var.project_id
}

# Grant GCS access
resource "google_storage_bucket_iam_member" "snowflake_loader_staging" {
  bucket = google_storage_bucket.snowflake_staging.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.snowflake_loader.email}"
}

# Grant Secret Manager access
resource "google_secret_manager_secret_iam_member" "snowflake_loader_secret" {
  secret_id = google_secret_manager_secret.snowflake_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.snowflake_loader.email}"
}

# Dataproc job to load Snowflake
resource "google_cloud_scheduler_job" "snowflake_etl_trigger" {
  name        = "snowflake-etl-trigger-${var.environment}"
  description = "Trigger Snowflake ETL job daily"
  schedule    = "0 2 * * *"  # 2 AM daily
  time_zone   = "America/New_York"
  region      = var.region

  http_target {
    http_method = "POST"
    uri         = "https://dataproc.googleapis.com/v1/projects/${var.project_id}/regions/${var.region}/batches"
    
    oauth_token {
      service_account_email = var.service_account
    }
    
    body = base64encode(jsonencode({
      pysparkBatch = {
        mainPythonFileUri = "gs://${var.staging_bucket}/pyspark-jobs/etl_transform_snowflake.py"
        args = [
          "--project-id=${var.project_id}",
          "--environment=${var.environment}",
          "--date={{ ds }}",
          "--method=copy"
        ]
      }
      environmentConfig = {
        executionConfig = {
          serviceAccount = google_service_account.snowflake_loader.email
        }
      }
      runtimeConfig = {
        version = "2.1"
        properties = {
          "spark.executor.instances" = "2"
          "spark.executor.cores"     = "4"
          "spark.driver.cores"       = "4"
        }
      }
    }))
  }

  retry_config {
    retry_count          = 3
    max_retry_duration   = "3600s"
    min_backoff_duration = "60s"
    max_backoff_duration = "600s"
  }
}
```

---

## Best Practices

### ✅ Do's

1. **Use Batch Mode**
   - Process thousands/millions of records at once
   - Avoid row-by-row INSERT statements

2. **Implement Idempotency**
   - Make jobs safe to re-run
   - Use partition overwrite or DELETE before INSERT

3. **Handle Errors Gracefully**
   - Use `ON_ERROR = 'CONTINUE'` for resilience
   - Log errors to tracking table
   - Quarantine failed batches

4. **Use Exponential Backoff**
   - Wait progressively longer between retries
   - Avoid hammering failed services

5. **Monitor and Alert**
   - Query COPY_HISTORY regularly
   - Alert on high error rates
   - Track data freshness SLAs

6. **Secure Credentials**
   - Use Secret Manager for passwords
   - Rotate credentials regularly
   - Use service accounts with minimal permissions

7. **Optimize File Sizes**
   - Target 100-250 MB files for Parquet
   - Avoid very small files (<1 MB)
   - Compress with Snappy or Gzip

8. **Partition Data**
   - Partition by date for faster queries
   - Use clustering keys for frequently filtered columns

### ❌ Don'ts

1. **Don't Use Row-by-Row Processing**
   - Extremely slow and expensive
   - Generates too many micro-transactions

2. **Don't Ignore Errors**
   - Always check COPY_HISTORY
   - Alert on failures

3. **Don't Skip Validation**
   - Use VALIDATION_MODE before production loads
   - Test with sample data first

4. **Don't Hardcode Credentials**
   - Use Secret Manager or environment variables
   - Never commit passwords to Git

5. **Don't Load Without Deduplication**
   - Check for existing data before loading
   - Implement merge logic if needed

---

## Performance Comparison

| Method | 1M Records | 10M Records | 100M Records |
|--------|-----------|-------------|--------------|
| **COPY INTO (Parquet)** | ~30 sec | ~3 min | ~20 min |
| **Spark Connector** | ~60 sec | ~8 min | ~45 min |
| **Snowpipe** | ~2 min | ~15 min | ~90 min |
| **INSERT (row-by-row)** | ~2 hours | ~20 hours | ~8 days |

*Actual performance varies based on cluster size, network, and data complexity*

---

## Monitoring Queries

```sql
-- Daily load summary
SELECT 
    DATE(last_load_time) as load_date,
    table_name,
    COUNT(*) as load_count,
    SUM(row_count) as total_rows,
    SUM(file_size) as total_size_bytes,
    SUM(error_count) as total_errors,
    AVG(DATEDIFF('second', first_load_time, last_load_time)) as avg_load_time_sec
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    START_TIME => DATEADD(days, -7, CURRENT_TIMESTAMP())
))
GROUP BY DATE(last_load_time), table_name
ORDER BY load_date DESC;

-- Error rate trend
SELECT 
    DATE_TRUNC('hour', last_load_time) as hour,
    COUNT(*) as load_attempts,
    SUM(CASE WHEN status = 'Loaded' THEN 1 ELSE 0 END) as successful,
    SUM(CASE WHEN status != 'Loaded' THEN 1 ELSE 0 END) as failed,
    ROUND(failed / load_attempts * 100, 2) as error_rate_pct
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    START_TIME => DATEADD(days, -1, CURRENT_TIMESTAMP())
))
GROUP BY DATE_TRUNC('hour', last_load_time)
ORDER BY hour DESC;

-- Current warehouse utilization
SELECT 
    warehouse_name,
    avg_running,
    avg_queued_load,
    avg_queued_provisioning,
    avg_blocked
FROM TABLE(INFORMATION_SCHEMA.WAREHOUSE_LOAD_HISTORY(
    DATE_RANGE_START => DATEADD(hours, -1, CURRENT_TIMESTAMP())
));
```

---

## Additional Resources

- [Snowflake Spark Connector Documentation](https://docs.snowflake.com/en/user-guide/spark-connector)
- [COPY INTO Command Reference](https://docs.snowflake.com/en/sql-reference/sql/copy-into-table)
- [Snowpipe Guide](https://docs.snowflake.com/en/user-guide/data-load-snowpipe)
- [Error Handling Best Practices](https://docs.snowflake.com/en/user-guide/data-load-error-handling)
- [GCS External Stages](https://docs.snowflake.com/en/user-guide/data-load-gcs)

---

## Next Steps

1. Set up Snowflake account and warehouse
2. Create storage integration for GCS access
3. Configure Secret Manager with Snowflake credentials
4. Deploy modified PySpark job
5. Test with sample data
6. Monitor COPY_HISTORY for errors
7. Set up alerting for failures
8. Optimize based on data volumes

For questions or issues, refer to the main [README.md](README.md) or contact the data engineering team.
