#!/bin/bash
#
# Deploy script for GCP Data Pipeline
# Usage: ./scripts/deploy.sh [environment]
#

set -e

ENVIRONMENT=${1:-dev}
PROJECT_ID=${GCP_PROJECT_ID}
REGION=${GCP_REGION:-us-central1}

echo "🚀 Deploying GCP Data Pipeline"
echo "   Environment: $ENVIRONMENT"
echo "   Project: $PROJECT_ID"
echo "   Region: $REGION"
echo ""

# Check prerequisites
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform is required but not installed."; exit 1; }
command -v gcloud >/dev/null 2>&1 || { echo "❌ gcloud CLI is required but not installed."; exit 1; }

# Authenticate
echo "🔐 Checking GCP authentication..."
gcloud auth application-default print-access-token > /dev/null 2>&1 || {
    echo "Please authenticate with GCP:"
    gcloud auth application-default login
}

# Deploy Terraform
echo ""
echo "📦 Deploying Terraform infrastructure..."
cd terraform

terraform init
terraform plan -var="project_id=$PROJECT_ID" -var="region=$REGION" -var="environment=$ENVIRONMENT" -out=tfplan
terraform apply tfplan

echo ""
echo "📤 Uploading PySpark jobs..."
gsutil cp ../pyspark-jobs/*.py gs://${PROJECT_ID}-staging-${ENVIRONMENT}/pyspark-jobs/
gsutil cp ../pyspark-jobs/requirements.txt gs://${PROJECT_ID}-staging-${ENVIRONMENT}/pyspark-jobs/

echo ""
echo "📤 Packaging and uploading Cloud Functions..."

# Package and upload data ingestion function
cd ../functions/data-ingestion
zip -r data-ingestion.zip main.py requirements.txt
gsutil cp data-ingestion.zip gs://${PROJECT_ID}-function-source-${ENVIRONMENT}/cloud-functions/
rm data-ingestion.zip

# Package and upload pubsub processor function
cd ../pubsub-processor
zip -r pubsub-processor.zip main.py requirements.txt
gsutil cp pubsub-processor.zip gs://${PROJECT_ID}-function-source-${ENVIRONMENT}/cloud-functions/
rm pubsub-processor.zip

cd ../..

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📊 Next steps:"
echo "   1. Test data ingestion: curl -X POST [FUNCTION_URL] -H 'Content-Type: application/json' -d '{...}'"
echo "   2. Submit PySpark job: gcloud dataproc batches submit pyspark gs://${PROJECT_ID}-staging-${ENVIRONMENT}/pyspark-jobs/etl_transform.py --region=$REGION"
echo "   3. Query BigQuery: bq query 'SELECT * FROM ${PROJECT_ID}.data_warehouse_${ENVIRONMENT}.analytics_data LIMIT 10'"
echo ""
echo "🔗 View resources:"
terraform -chdir=terraform output
