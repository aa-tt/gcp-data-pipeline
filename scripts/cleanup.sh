#!/bin/bash
#
# Cleanup script for GCP Data Pipeline
# WARNING: This will destroy all resources!
#

set -e

ENVIRONMENT=${1:-dev}
PROJECT_ID=${GCP_PROJECT_ID}

echo "⚠️  WARNING: This will destroy all GCP Data Pipeline resources!"
echo "   Environment: $ENVIRONMENT"
echo "   Project: $PROJECT_ID"
echo ""
read -p "Are you sure? (yes/NO) " -r
echo

if [[ ! $REPLY =~ ^yes$ ]]; then
    echo "❌ Cleanup cancelled"
    exit 0
fi

echo "🗑️  Cleaning up GCP Data Pipeline..."

# Destroy Terraform resources
echo ""
echo "Destroying Terraform resources..."
cd terraform
terraform destroy -var="project_id=$PROJECT_ID" -var="environment=$ENVIRONMENT" -auto-approve
cd ..

# Clean up any remaining buckets (force delete)
echo ""
echo "Cleaning up storage buckets..."
for bucket in raw-data processed-data staging archive function-source; do
    BUCKET_NAME="${PROJECT_ID}-${bucket}-${ENVIRONMENT}"
    if gsutil ls gs://${BUCKET_NAME} > /dev/null 2>&1; then
        echo "Deleting bucket: $BUCKET_NAME"
        gsutil -m rm -r gs://${BUCKET_NAME}/* || true
        gsutil rb gs://${BUCKET_NAME} || true
    fi
done

echo ""
echo "✅ Cleanup complete!"
