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


