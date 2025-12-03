#!/bin/bash
# Setup Cloud Monitoring Alerts for the Data Pipeline

set -e

PROJECT_ID=${1:-"datapipeline-480007"}
ENVIRONMENT=${2:-"dev"}
REGION="us-central1"

echo "Setting up monitoring alerts for project: $PROJECT_ID, environment: $ENVIRONMENT"

# Create notification channel (email)
echo "Creating notification channel..."
CHANNEL_ID=$(gcloud alpha monitoring channels create \
  --display-name="Data Pipeline Alerts - $ENVIRONMENT" \
  --type=email \
  --channel-labels=email_address=$(gcloud config get-value account) \
  --project=$PROJECT_ID \
  --format="value(name)")

echo "Notification channel created: $CHANNEL_ID"

# Alert 1: Cloud Function Errors
echo "Creating alert for Cloud Function errors..."
gcloud alpha monitoring policies create \
  --notification-channels=$CHANNEL_ID \
  --display-name="Cloud Function Errors - $ENVIRONMENT" \
  --condition-display-name="Function error rate > 5%" \
  --condition-threshold-value=0.05 \
  --condition-threshold-duration=300s \
  --condition-threshold-filter='resource.type="cloud_function" AND metric.type="cloudfunctions.googleapis.com/function/execution_count" AND metric.labels.status!="ok"' \
  --aggregation-alignment-period=60s \
  --aggregation-per-series-aligner=ALIGN_RATE \
  --aggregation-cross-series-reducer=REDUCE_SUM \
  --project=$PROJECT_ID || echo "Alert may already exist"

# Alert 2: Dataproc Batch Failures
echo "Creating alert for Dataproc batch failures..."
gcloud alpha monitoring policies create \
  --notification-channels=$CHANNEL_ID \
  --display-name="Dataproc Batch Failures - $ENVIRONMENT" \
  --condition-display-name="Dataproc batch failed" \
  --condition-threshold-value=1 \
  --condition-threshold-duration=60s \
  --condition-threshold-filter='resource.type="cloud_dataproc_batch" AND metric.type="dataproc.googleapis.com/batch/state" AND metric.labels.state="FAILED"' \
  --aggregation-alignment-period=60s \
  --aggregation-per-series-aligner=ALIGN_MAX \
  --project=$PROJECT_ID || echo "Alert may already exist"

# Alert 3: BigQuery Job Errors
echo "Creating alert for BigQuery errors..."
gcloud alpha monitoring policies create \
  --notification-channels=$CHANNEL_ID \
  --display-name="BigQuery Job Errors - $ENVIRONMENT" \
  --condition-display-name="BigQuery job failures" \
  --condition-threshold-value=1 \
  --condition-threshold-duration=300s \
  --condition-threshold-filter='resource.type="bigquery_project" AND metric.type="bigquery.googleapis.com/job/num_failed_jobs"' \
  --aggregation-alignment-period=60s \
  --aggregation-per-series-aligner=ALIGN_DELTA \
  --aggregation-cross-series-reducer=REDUCE_SUM \
  --project=$PROJECT_ID || echo "Alert may already exist"

# Alert 4: High Cost Alert (Budget)
echo "Creating budget alert..."
gcloud billing budgets create \
  --billing-account=$(gcloud billing projects describe $PROJECT_ID --format="value(billingAccountName)") \
  --display-name="Monthly Budget Alert - $ENVIRONMENT" \
  --budget-amount=100 \
  --threshold-rule=percent=50 \
  --threshold-rule=percent=90 \
  --threshold-rule=percent=100 \
  --filter-projects=$PROJECT_ID || echo "Budget alert may already exist"

echo ""
echo "✅ Monitoring alerts setup complete!"
echo ""
echo "To view alerts:"
echo "  gcloud alpha monitoring policies list --project=$PROJECT_ID"
echo ""
echo "To view notification channels:"
echo "  gcloud alpha monitoring channels list --project=$PROJECT_ID"
