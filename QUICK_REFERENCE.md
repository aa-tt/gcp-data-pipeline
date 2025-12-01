# Quick Reference Guide

## Common Commands

### Setup & Deployment

```bash
# Set environment variables
export GCP_PROJECT_ID="your-project-id"
export GCP_REGION="us-central1"
export ENVIRONMENT="dev"

# Deploy infrastructure
cd terraform
terraform init
terraform apply -var="project_id=$GCP_PROJECT_ID" -var="region=$GCP_REGION"

# Quick deploy using script
./scripts/deploy.sh dev
```

### Testing

```bash
# Run all tests
./scripts/test.sh dev

# Test Pub/Sub
gcloud pubsub topics publish raw-data-topic-dev \
    --message='{"test": "data"}'

# Test Cloud Function
FUNCTION_URL=$(gcloud functions describe data-ingestion-dev \
    --region=$GCP_REGION --gen2 --format="value(serviceConfig.uri)")

curl -X POST "$FUNCTION_URL" \
    -H "Content-Type: application/json" \
    -d '{"data_type": "test", "payload": {"amount": 100}}'

# Submit PySpark job
gcloud dataproc batches submit pyspark \
    gs://${GCP_PROJECT_ID}-staging-dev/pyspark-jobs/etl_transform.py \
    --region=$GCP_REGION \
    --service-account=data-pipeline-sa-dev@${GCP_PROJECT_ID}.iam.gserviceaccount.com \
    -- --project-id=$GCP_PROJECT_ID --environment=dev --date=$(date -u +%Y-%m-%d)
```

### Monitoring

```bash
# View Cloud Function logs
gcloud functions logs read data-ingestion-dev --region=$GCP_REGION --limit=50

# View Dataproc batch logs
gcloud dataproc batches list --region=$GCP_REGION
gcloud dataproc batches describe BATCH_ID --region=$GCP_REGION

# Query BigQuery
bq query --use_legacy_sql=false \
    'SELECT * FROM `'${GCP_PROJECT_ID}'.data_warehouse_dev.analytics_data` LIMIT 10'

# List Pub/Sub messages
gcloud pubsub subscriptions pull raw-data-processing-sub-dev --limit=5
```

### Maintenance

```bash
# Update PySpark jobs
gsutil cp pyspark-jobs/*.py gs://${GCP_PROJECT_ID}-staging-dev/pyspark-jobs/

# Update Cloud Functions
cd functions/data-ingestion
zip -r data-ingestion.zip main.py requirements.txt
gsutil cp data-ingestion.zip gs://${GCP_PROJECT_ID}-function-source-dev/cloud-functions/

# Update Airflow DAGs
DAG_BUCKET=$(gcloud composer environments describe data-pipeline-dev \
    --location $GCP_REGION --format="get(config.dagGcsPrefix)")
gsutil cp airflow-dags/*.py $DAG_BUCKET/

# Check Terraform state
cd terraform
terraform state list
terraform show
```

### Cleanup

```bash
# Destroy all resources
./scripts/cleanup.sh dev

# Or manually
cd terraform
terraform destroy -var="project_id=$GCP_PROJECT_ID"
```

## Important GCS Paths

```bash
# Raw data
gs://${GCP_PROJECT_ID}-raw-data-${ENVIRONMENT}/

# Processed data
gs://${GCP_PROJECT_ID}-processed-data-${ENVIRONMENT}/

# Staging (PySpark jobs)
gs://${GCP_PROJECT_ID}-staging-${ENVIRONMENT}/pyspark-jobs/

# Cloud Functions source
gs://${GCP_PROJECT_ID}-function-source-${ENVIRONMENT}/cloud-functions/
```

## BigQuery Tables

```sql
-- Raw data table
`${GCP_PROJECT_ID}.data_warehouse_${ENVIRONMENT}.raw_data`

-- Analytics table
`${GCP_PROJECT_ID}.data_warehouse_${ENVIRONMENT}.analytics_data`

-- Metrics table
`${GCP_PROJECT_ID}.data_warehouse_${ENVIRONMENT}.daily_metrics`

-- Latest view
`${GCP_PROJECT_ID}.data_warehouse_${ENVIRONMENT}.latest_analytics_view`
```

## Useful SQL Queries

```sql
-- Count records by date
SELECT 
    DATE(ingestion_timestamp) as date,
    COUNT(*) as records
FROM `${GCP_PROJECT_ID}.data_warehouse_dev.raw_data`
GROUP BY date
ORDER BY date DESC;

-- Check data quality
SELECT 
    COUNT(*) as total_records,
    COUNTIF(amount IS NULL) as null_amounts,
    COUNTIF(amount < 0) as negative_amounts
FROM `${GCP_PROJECT_ID}.data_warehouse_dev.analytics_data`
WHERE event_date = CURRENT_DATE();

-- Top categories by revenue
SELECT 
    category,
    SUM(amount) as total_revenue,
    COUNT(*) as transactions
FROM `${GCP_PROJECT_ID}.data_warehouse_dev.analytics_data`
WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
GROUP BY category
ORDER BY total_revenue DESC;

-- Daily metrics summary
SELECT 
    metric_date,
    metric_name,
    SUM(value) as total_value
FROM `${GCP_PROJECT_ID}.data_warehouse_dev.daily_metrics`
WHERE metric_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY metric_date, metric_name
ORDER BY metric_date DESC;
```

## Pub/Sub Topics

```bash
# Raw data topic
raw-data-topic-${ENVIRONMENT}

# Processed data topic
processed-data-topic-${ENVIRONMENT}

# Dead letter topic
dead-letter-topic-${ENVIRONMENT}

# Batch trigger topic
batch-trigger-topic-${ENVIRONMENT}
```

## IAM Roles

```bash
# Service account
data-pipeline-sa-${ENVIRONMENT}@${GCP_PROJECT_ID}.iam.gserviceaccount.com

# Required roles
roles/dataproc.worker
roles/bigquery.dataEditor
roles/bigquery.jobUser
roles/storage.objectAdmin
roles/pubsub.editor
roles/logging.logWriter
```

## Environment Variables

### For Local Development

```bash
export GCP_PROJECT_ID="your-project-id"
export GCP_REGION="us-central1"
export ENVIRONMENT="dev"
export GOOGLE_APPLICATION_CREDENTIALS="~/terraform-key.json"
```

### For GitHub Actions

Add these secrets:
- `GCP_PROJECT_ID`: Your project ID
- `GCP_SA_KEY`: Service account key (base64 encoded)
- `GCP_REGION`: Deployment region

## Troubleshooting

### Cloud Function Issues

```bash
# Check function status
gcloud functions describe data-ingestion-dev --region=$GCP_REGION --gen2

# View recent errors
gcloud functions logs read data-ingestion-dev \
    --region=$GCP_REGION --limit=50 | grep ERROR

# Test locally
cd functions/data-ingestion
python main.py
```

### Dataproc Issues

```bash
# List recent batches
gcloud dataproc batches list --region=$GCP_REGION

# Get batch details
gcloud dataproc batches describe BATCH_ID --region=$GCP_REGION

# View logs
gcloud logging read "resource.type=dataproc.googleapis.com/Batch" \
    --limit=50 --format=json
```

### BigQuery Issues

```bash
# Check table schema
bq show --schema ${GCP_PROJECT_ID}:data_warehouse_dev.analytics_data

# Validate data
bq query --use_legacy_sql=false \
    'SELECT COUNT(*) FROM `'${GCP_PROJECT_ID}'.data_warehouse_dev.analytics_data`'

# Check query jobs
bq ls -j -a --max_results=10
```

### Permission Issues

```bash
# Check service account permissions
gcloud projects get-iam-policy $GCP_PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.members:data-pipeline-sa-dev@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

# Grant missing role
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="serviceAccount:data-pipeline-sa-dev@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/ROLE_NAME"
```

## Performance Tuning

### BigQuery

```sql
-- Enable partition pruning
WHERE event_date = '2024-01-15'  -- Good
WHERE DATE(event_timestamp) = '2024-01-15'  -- Bad (scans all data)

-- Use clustering
WHERE category = 'electronics' AND region = 'us-west'  -- Efficient with clustering
```

### Dataproc

```bash
# Increase worker memory
--properties spark.executor.memory=8g

# Increase parallelism
--properties spark.sql.shuffle.partitions=200

# Enable adaptive query execution
--properties spark.sql.adaptive.enabled=true
```

### Cloud Functions

```bash
# Increase memory for CPU-intensive tasks
gcloud functions deploy FUNCTION_NAME --memory=1GB

# Increase timeout
gcloud functions deploy FUNCTION_NAME --timeout=300s

# Increase max instances
gcloud functions deploy FUNCTION_NAME --max-instances=100
```

## Cost Monitoring

```bash
# Check current month costs
gcloud billing accounts list
gcloud billing projects describe $GCP_PROJECT_ID

# Export to BigQuery for analysis
bq query --use_legacy_sql=false \
    'SELECT service.description, SUM(cost) as total_cost
     FROM `'${GCP_PROJECT_ID}'.billing.gcp_billing_export_v1_*`
     WHERE DATE(usage_start_time) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
     GROUP BY service.description
     ORDER BY total_cost DESC'

# Set budget alert
gcloud billing budgets create \
    --billing-account=BILLING_ACCOUNT_ID \
    --display-name="Data Pipeline Budget" \
    --budget-amount=500
```

## Backup & Recovery

```bash
# Export BigQuery table
bq extract --destination_format=PARQUET \
    ${GCP_PROJECT_ID}:data_warehouse_dev.analytics_data \
    gs://${GCP_PROJECT_ID}-archive-dev/backups/analytics_data_*.parquet

# Copy Cloud Storage bucket
gsutil -m rsync -r \
    gs://${GCP_PROJECT_ID}-processed-data-dev/ \
    gs://${GCP_PROJECT_ID}-backup-dev/

# Export Terraform state
cd terraform
terraform state pull > terraform-state-backup.json
```

## Links

- **Cloud Console**: https://console.cloud.google.com
- **BigQuery UI**: https://console.cloud.google.com/bigquery
- **Cloud Functions**: https://console.cloud.google.com/functions
- **Dataproc**: https://console.cloud.google.com/dataproc
- **Monitoring**: https://console.cloud.google.com/monitoring
- **Logging**: https://console.cloud.google.com/logs
- **Billing**: https://console.cloud.google.com/billing
