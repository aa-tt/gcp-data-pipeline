# Core Permissions
gcloud projects add-iam-policy-binding datapipeline-480007 \
  --member="serviceAccount:terraform-sa@datapipeline-480007.iam.gserviceaccount.com" \
  --role="roles/editor"

# IAM Management
gcloud projects add-iam-policy-binding datapipeline-480007 \
  --member="serviceAccount:terraform-sa@datapipeline-480007.iam.gserviceaccount.com" \
  --role="roles/resourcemanager.projectIamAdmin"

gcloud projects add-iam-policy-binding datapipeline-480007 \
  --member="serviceAccount:terraform-sa@datapipeline-480007.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountAdmin"

# API Management
gcloud projects add-iam-policy-binding datapipeline-480007 \
  --member="serviceAccount:terraform-sa@datapipeline-480007.iam.gserviceaccount.com" \
  --role="roles/serviceusage.serviceUsageAdmin"

# BigQuery Admin
gcloud projects add-iam-policy-binding datapipeline-480007 \
  --member="serviceAccount:terraform-sa@datapipeline-480007.iam.gserviceaccount.com" \
  --role="roles/bigquery.admin"

# Storage Admin  
gcloud projects add-iam-policy-binding datapipeline-480007 \
  --member="serviceAccount:terraform-sa@datapipeline-480007.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

# Pub/Sub Admin
gcloud projects add-iam-policy-binding datapipeline-480007 \
  --member="serviceAccount:terraform-sa@datapipeline-480007.iam.gserviceaccount.com" \
  --role="roles/pubsub.admin"

# Cloud Functions Admin
gcloud projects add-iam-policy-binding datapipeline-480007 \
  --member="serviceAccount:terraform-sa@datapipeline-480007.iam.gserviceaccount.com" \
  --role="roles/cloudfunctions.admin"

# Cloud Scheduler Admin
gcloud projects add-iam-policy-binding datapipeline-480007 \
  --member="serviceAccount:terraform-sa@datapipeline-480007.iam.gserviceaccount.com" \
  --role="roles/cloudscheduler.admin"

# Dataproc Admin (likely needed next)
gcloud projects add-iam-policy-binding datapipeline-480007 \
  --member="serviceAccount:terraform-sa@datapipeline-480007.iam.gserviceaccount.com" \
  --role="roles/dataproc.admin"

# Compute Admin (needed for Cloud Functions)
gcloud projects add-iam-policy-binding datapipeline-480007 \
  --member="serviceAccount:terraform-sa@datapipeline-480007.iam.gserviceaccount.com" \
  --role="roles/compute.admin"

## The terraform-sa needs permission to impersonate the data-pipeline-sa-dev service account.
# 1. Add missing IAM role
gcloud projects add-iam-policy-binding datapipeline-480007 \
  --member="serviceAccount:terraform-sa@datapipeline-480007.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

# 2. Upload function code
cd /gcp-data-pipeline/functions/data-ingestion
zip -r data-ingestion.zip main.py requirements.txt
gsutil cp data-ingestion.zip gs://datapipeline-480007-function-source-dev/cloud-functions/

cd ../pubsub-processor
zip -r pubsub-processor.zip main.py requirements.txt
gsutil cp pubsub-processor.zip gs://datapipeline-480007-function-source-dev/cloud-functions/

# 3. Retry Terraform
cd /Users/ananindy/aa/gcp-data-pipeline/terraform
terraform apply



# Next steps after tf apply
1. Upload PySpark Job Code
cd /gcp-data-pipeline

## Upload PySpark jobs to staging bucket
gsutil cp pyspark-jobs/*.py gs://datapipeline-480007-staging-dev/pyspark-jobs/
gsutil cp pyspark-jobs/requirements.txt gs://datapipeline-480007-staging-dev/pyspark-jobs/
terraform apply -replace="module.cloud_functions.google_cloudfunctions2_function.data_ingestion" -replace="module.cloud_functions.google_cloudfunctions2_function.pubsub_processor" 

2. Test the Data Ingestion Function
# Fix current deployment
gcloud functions delete data-ingestion-dev --gen2 --region=us-central1 --quiet
gcloud functions delete pubsub-processor-dev --gen2 --region=us-central1 --quiet
# Redeploy with Terraform (function code is already uploaded)
cd /gcp-data-pipeline/terraform
terraform apply
# Fix The pubsub-processor-dev function is not authenticated to be triggered by Pub/Sub
gcloud functions add-invoker-policy-binding pubsub-processor-dev \
  --region=us-central1 \
  --member="serviceAccount:service-752977353420@gcp-sa-pubsub.iam.gserviceaccount.com"

# Test with a simple POST request
curl -X POST "https://data-ingestion-dev-752977353420.us-central1.run.app" \
    -H "Authorization: bearer $(gcloud auth print-identity-token)" \
    -H "Content-Type: application/json" \
    -d '{
        "data_type": "transaction",
            "payload": {
                "user_id": "user-123",
                "amount": 50.00,
                "category": "shopping",
                "region": "us-west"
            }
        }'

3. Test Pub/Sub Publishing
# Note: There's a typo in the output ("gloud" should be "gcloud")
gcloud pubsub topics publish projects/datapipeline-480007/topics/raw-data-topic-dev \
  --message='{"test": "data"}'

4. Verify Data in BigQuery
gcloud projects add-iam-policy-binding datapipeline-480007 \
  --member="user:i.anunay@gmail.com" \
  --role="roles/bigquery.admin"
# Check raw data table
bq query --use_legacy_sql=false \
  'SELECT * FROM `datapipeline-480007.data_warehouse_dev.raw_data` LIMIT 10'

5. Run a Dataproc Batch Job
gcloud dataproc batches submit pyspark \
  gs://datapipeline-480007-staging-dev/pyspark-jobs/etl_transform.py \
  --region=us-central1 \
  --service-account=data-pipeline-sa-dev@datapipeline-480007.iam.gserviceaccount.com \
  -- \
  --project-id=datapipeline-480007 \
  --environment=dev \
  --date=$(date -u +%Y-%m-%d)


6. PySpark job. It reads from BigQuery raw_data, transforms it, and writes to analytics_data, Upload the PySpark job to GCS:

gsutil cp pyspark-jobs/*.py gs://datapipeline-480007-staging-dev/pyspark-jobs/ && gsutil cp pyspark-jobs/requirements.txt gs://datapipeline-480007-staging-dev/pyspark-jobs/

7. manually inserting test data into BigQuery

bq query --use_legacy_sql=false --format=pretty --project_id=datapipeline-480007 "
INSERT INTO \`datapipeline-480007.data_warehouse_dev.raw_data\` (id, ingestion_timestamp, source_system, data_type, raw_payload, metadata)
VALUES 
  ('txn-001', TIMESTAMP('2025-12-03 16:00:00'), 'api', 'transaction', JSON'{\"user_id\":\"user-123\",\"product_id\":\"PROD-001\",\"amount\":150.50,\"quantity\":2,\"category\":\"electronics\",\"region\":\"us-west\"}', STRUCT('1.0' AS version, 'dev' AS environment)),
  ('txn-002', TIMESTAMP('2025-12-03 16:15:00'), 'api', 'transaction', JSON'{\"user_id\":\"user-456\",\"product_id\":\"PROD-002\",\"amount\":75.25,\"quantity\":1,\"category\":\"books\",\"region\":\"us-east\"}', STRUCT('1.0' AS version, 'dev' AS environment)),
  ('txn-003', TIMESTAMP('2025-12-03 16:30:00'), 'api', 'transaction', JSON'{\"user_id\":\"user-789\",\"product_id\":\"PROD-003\",\"amount\":200.00,\"quantity\":3,\"category\":\"electronics\",\"region\":\"eu-west\"}', STRUCT('1.0' AS version, 'dev' AS environment))
"

verify data:
bq query --use_legacy_sql=false --format=pretty "SELECT id, data_type, JSON_EXTRACT_SCALAR(raw_payload, '$.user_id') as user_id, JSON_EXTRACT_SCALAR(raw_payload, '$.amount') as amount FROM \`datapipeline-480007.data_warehouse_dev.raw_data\`"

8. run the PySpark job using Dataproc Serverless:

gcloud dataproc batches submit pyspark \
  gs://datapipeline-480007-staging-dev/pyspark-jobs/etl_transform.py \
  --region=us-central1 \
  --project=datapipeline-480007 \
  --service-account=data-pipeline-sa-dev@datapipeline-480007.iam.gserviceaccount.com \
  -- \
  --project-id=datapipeline-480007 \
  --environment=dev \
  --date=2025-12-03

  Batch [f72644b164cf441ebb744232562caef2] submitted.

9. check status
gcloud dataproc batches describe f72644b164cf441ebb744232562caef2 --region=us-central1 --format="value(state,stateTime)"

10. check error logs
gcloud dataproc batches describe f72644b164cf441ebb744232562caef2 --region=us-central1 --format="value(stateMessage)"

11. dataproc read permission to big query for sa account
gcloud projects add-iam-policy-binding datapipeline-480007 \
  --member="serviceAccount:data-pipeline-sa-dev@datapipeline-480007.iam.gserviceaccount.com" \
  --role="roles/bigquery.readSessionUser"

12. resubmit dataproc pyspark job
✅ Success Summary
The Dataproc batch ETL job has completed successfully! Here's what was accomplished:

Issues Fixed:
Schema Mismatch - event_timestamp: Fixed conversion from STRING to TIMESTAMP type

Updated etl_transform.py to properly convert ingestion_timestamp using F.to_timestamp()
Schema Mismatch - attributes field: Changed from JSON to STRING type

Recreated analytics_data table with correct schema matching PySpark output
Added missing transaction_id field
Schema Mismatch - daily_metrics value field: Changed from NUMERIC to FLOAT type

Recreated daily_metrics table with FLOAT type for the value field
Results:
✅ analytics_data table: 6 rows successfully loaded

Contains transformed event data with proper timestamps
Includes fields: event_date, event_timestamp, user_id, product_id, transaction_id, category, region, amount, quantity, attributes
✅ daily_metrics table: 2 metric records successfully loaded

Contains aggregated daily metrics
Includes fields: metric_date, metric_name, dimension, value, count
✅ GCS backup: Data also written to gs://datapipeline-480007-processed-data-dev/analytics/2025-12-03/ in Parquet format

Pipeline Execution Details:
Input: 5 JSON files from GCS
Records Read: 5 total records
Transformed Output: 3 records (filtered for valid transactions with amount > 0)
Metrics Generated: 2 aggregated metric records
Status: ✅ SUCCEEDED


13. testing cloud scheduler

> gcloud scheduler jobs list --location=us-central1 --project=datapipeline-480007
ID                     LOCATION     SCHEDULE (TZ)                 TARGET_TYPE  STATE
daily-etl-trigger-dev  us-central1  0 2 * * * (America/New_York)  HTTP         ENABLED

> gcloud scheduler jobs list --location=us-central1 --project=datapipeline-480007
should trigger dataproc job

gcloud dataproc batches list --region=us-central1 --project=datapipeline-480007 --limit=5

sa shoudl have dataproc.editor/admin role to submit dataproc batch from scheduler job
gcloud projects add-iam-policy-binding datapipeline-480007 \
  --member="serviceAccount:data-pipeline-sa-dev@datapipeline-480007.iam.gserviceaccount.com" \
  --role="roles/dataproc.editor"