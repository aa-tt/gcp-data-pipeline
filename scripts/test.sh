#!/bin/bash
#
# Test script for GCP Data Pipeline
# Tests each component of the pipeline
#

set -e

ENVIRONMENT=${1:-dev}
PROJECT_ID=${GCP_PROJECT_ID}
REGION=${GCP_REGION:-us-central1}

echo "🧪 Testing GCP Data Pipeline"
echo "   Environment: $ENVIRONMENT"
echo ""

# Test 1: Publish test message to Pub/Sub
echo "📤 Test 1: Publishing test message to Pub/Sub..."
gcloud pubsub topics publish raw-data-topic-${ENVIRONMENT} \
    --message='{"test": "data", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'
echo "✅ Message published"

# Test 2: Call Cloud Function
echo ""
echo "📤 Test 2: Testing Cloud Function..."
FUNCTION_URL=$(gcloud functions describe data-ingestion-${ENVIRONMENT} \
    --region=$REGION \
    --gen2 \
    --format="value(serviceConfig.uri)" 2>/dev/null || echo "")

if [ -n "$FUNCTION_URL" ]; then
    curl -X POST "$FUNCTION_URL" \
        -H "Content-Type: application/json" \
        -d '{
            "data_type": "test-transaction",
            "source_system": "test-system",
            "payload": {
                "user_id": "user-123",
                "product_id": "prod-456",
                "amount": 99.99,
                "quantity": 2,
                "category": "electronics",
                "region": "us-west"
            }
        }'
    echo ""
    echo "✅ Cloud Function called"
else
    echo "⚠️  Cloud Function not deployed yet"
fi

# Test 3: Check Cloud Storage buckets
echo ""
echo "📦 Test 3: Checking Cloud Storage buckets..."
for bucket in raw-data processed-data staging; do
    if gsutil ls gs://${PROJECT_ID}-${bucket}-${ENVIRONMENT} > /dev/null 2>&1; then
        echo "✅ Bucket gs://${PROJECT_ID}-${bucket}-${ENVIRONMENT} exists"
    else
        echo "❌ Bucket gs://${PROJECT_ID}-${bucket}-${ENVIRONMENT} not found"
    fi
done

# Test 4: Check BigQuery tables
echo ""
echo "📊 Test 4: Checking BigQuery tables..."
for table in raw_data analytics_data daily_metrics; do
    if bq show ${PROJECT_ID}:data_warehouse_${ENVIRONMENT}.${table} > /dev/null 2>&1; then
        echo "✅ Table ${table} exists"
        # Show row count
        COUNT=$(bq query --use_legacy_sql=false --format=csv \
            "SELECT COUNT(*) as count FROM ${PROJECT_ID}.data_warehouse_${ENVIRONMENT}.${table}" 2>/dev/null | tail -1)
        echo "   Records: $COUNT"
    else
        echo "❌ Table ${table} not found"
    fi
done

# Test 5: Submit a test PySpark job
echo ""
echo "🔥 Test 5: Submitting test PySpark job..."
read -p "Submit test PySpark job? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    gcloud dataproc batches submit pyspark \
        gs://${PROJECT_ID}-staging-${ENVIRONMENT}/pyspark-jobs/etl_transform.py \
        --region=$REGION \
        --service-account=data-pipeline-sa-${ENVIRONMENT}@${PROJECT_ID}.iam.gserviceaccount.com \
        -- \
        --project-id=$PROJECT_ID \
        --environment=$ENVIRONMENT \
        --date=$(date -u +%Y-%m-%d)
    echo "✅ PySpark job submitted"
else
    echo "⏭️  Skipped PySpark job submission"
fi

echo ""
echo "✅ Testing complete!"
