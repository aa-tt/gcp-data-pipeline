# GCP Data Pipeline - Setup Guide

This guide walks you through setting up the complete GCP data pipeline from scratch.

## Prerequisites

### 1. Install Required Tools

```bash
# Install Google Cloud SDK
# macOS
brew install google-cloud-sdk

# Or download from: https://cloud.google.com/sdk/docs/install

# Install Terraform
brew install terraform

# Verify installations
gcloud --version
terraform --version
```

### 2. Create GCP Project

```bash
# Create a new project (or use existing)
export PROJECT_ID="your-project-id"
gcloud projects create $PROJECT_ID --name="Data Pipeline"

# Set as default project
gcloud config set project $PROJECT_ID

# Enable billing (required)
# Go to: https://console.cloud.google.com/billing
```

### 3. Authenticate with GCP

```bash
# Login to GCP
gcloud auth login

# Set application default credentials
gcloud auth application-default login

# Verify authentication
gcloud auth list
```

## Local Deployment

### Step 1: Configure Environment Variables

```bash
export GCP_PROJECT_ID="your-project-id"
export GCP_REGION="us-central1"
export ENVIRONMENT="dev"
```

Add to your `~/.zshrc` or `~/.bash_profile`:
```bash
echo "export GCP_PROJECT_ID='your-project-id'" >> ~/.zshrc
echo "export GCP_REGION='us-central1'" >> ~/.zshrc
source ~/.zshrc
```

### Step 2: Create Service Account for Terraform

```bash
# Create service account
gcloud iam service-accounts create terraform-sa \
    --display-name="Terraform Service Account"

# Grant necessary permissions
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="serviceAccount:terraform-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/editor"

gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="serviceAccount:terraform-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountAdmin"

# Generate key (keep this secure!)
gcloud iam service-accounts keys create ~/terraform-key.json \
    --iam-account=terraform-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com

# Set credentials
export GOOGLE_APPLICATION_CREDENTIALS=~/terraform-key.json
```

### Step 3: Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
vim terraform.tfvars
```

Update the following in `terraform.tfvars`:
```hcl
project_id  = "your-project-id"
region      = "us-central1"
environment = "dev"
enable_composer = false  # Set to true if you need Airflow
```

### Step 4: Deploy Infrastructure

```bash
### Step 4: Upload Cloud Function Source Code (Before Terraform Apply)

⚠️ **Important**: Upload function code BEFORE running `terraform apply` to avoid deployment issues.

```bash
# Package and upload data-ingestion function
cd functions/data-ingestion
zip -r data-ingestion.zip main.py requirements.txt
gsutil cp data-ingestion.zip gs://${GCP_PROJECT_ID}-function-source-dev/cloud-functions/

# Package and upload pubsub-processor function
cd ../pubsub-processor
zip -r pubsub-processor.zip main.py requirements.txt
gsutil cp pubsub-processor.zip gs://${GCP_PROJECT_ID}-function-source-dev/cloud-functions/

# Return to project root
cd ../..
```

### Step 5: Deploy Infrastructure with Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply (create resources including Cloud Functions with uploaded code)
terraform apply

# This will take 5-10 minutes
# Type 'yes' when prompted
```

### Step 6: Upload PySpark Jobs

```bash
# Upload PySpark jobs to staging bucket
cd ..
gsutil cp pyspark-jobs/*.py gs://${GCP_PROJECT_ID}-staging-dev/pyspark-jobs/
gsutil cp pyspark-jobs/requirements.txt gs://${GCP_PROJECT_ID}-staging-dev/pyspark-jobs/
```

### Step 7: Test the Pipeline

```bash
# Run test script
./scripts/test.sh dev
```

Or test manually:

```bash
# 1. Publish to Pub/Sub
gcloud pubsub topics publish raw-data-topic-dev \
    --message='{"test": "Hello, Pipeline!"}'

# 2. Test Cloud Function
FUNCTION_URL=$(gcloud functions describe data-ingestion-dev \
    --region=$GCP_REGION --gen2 --format="value(serviceConfig.uri)")

curl -X POST "$FUNCTION_URL" \
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

# 3. Check BigQuery
bq query --use_legacy_sql=false \
    'SELECT COUNT(*) FROM `'${GCP_PROJECT_ID}'.data_warehouse_dev.raw_data`'

# 4. Submit PySpark job
gcloud dataproc batches submit pyspark \
    gs://${GCP_PROJECT_ID}-staging-dev/pyspark-jobs/etl_transform.py \
    --region=$GCP_REGION \
    --service-account=data-pipeline-sa-dev@${GCP_PROJECT_ID}.iam.gserviceaccount.com \
    -- \
    --project-id=$GCP_PROJECT_ID \
    --environment=dev \
    --date=$(date -u +%Y-%m-%d)
```

## GitHub Actions CI/CD Setup

### Step 1: Create Service Account for GitHub Actions

```bash
# Create service account
gcloud iam service-accounts create github-actions-sa \
    --display-name="GitHub Actions Service Account"

# Grant permissions
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="serviceAccount:github-actions-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/editor"

# Generate key
gcloud iam service-accounts keys create ~/github-actions-key.json \
    --iam-account=github-actions-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com
```

### Step 2: Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add the following secrets:

1. **GCP_PROJECT_ID**: Your GCP project ID
2. **GCP_SA_KEY**: Contents of `github-actions-key.json`
   ```bash
   cat ~/github-actions-key.json | base64
   # Copy the output
   ```
3. **GCP_REGION**: `us-central1` (or your preferred region)

### Step 3: Push to GitHub

```bash
git init
git add .
git commit -m "Initial commit: GCP Data Pipeline"
git branch -M main
git remote add origin https://github.com/yourusername/gcp-data-pipeline.git
git push -u origin main
```

The GitHub Actions workflow will automatically:
1. Validate Terraform on PRs
2. Run security scans
3. Deploy infrastructure on merge to main
4. Deploy Cloud Functions and PySpark jobs
5. Run tests

## Enabling Cloud Composer (Airflow)

⚠️ **Note**: Cloud Composer costs ~$300/month minimum. Only enable if needed.

```bash
# Update terraform.tfvars
enable_composer = true

# Apply Terraform (will take 20-30 minutes)
terraform apply

# Upload DAGs
DAG_BUCKET=$(gcloud composer environments describe data-pipeline-dev \
    --location $GCP_REGION \
    --format="get(config.dagGcsPrefix)")

gsutil cp airflow-dags/*.py $DAG_BUCKET/

# Access Airflow UI
AIRFLOW_URL=$(gcloud composer environments describe data-pipeline-dev \
    --location $GCP_REGION \
    --format="get(config.airflowUri)")

echo "Airflow UI: $AIRFLOW_URL"
```

## Monitoring and Observability

### View Logs

```bash
# Cloud Functions logs
gcloud functions logs read data-ingestion-dev --region=$GCP_REGION

# Dataproc batch logs
gcloud dataproc batches list --region=$GCP_REGION
gcloud dataproc batches describe BATCH_ID --region=$GCP_REGION

# View in Cloud Console
open "https://console.cloud.google.com/logs/query?project=$GCP_PROJECT_ID"
```

### Set Up Alerts

```bash
# Create alert for failed Cloud Functions
gcloud alpha monitoring policies create \
    --notification-channels=CHANNEL_ID \
    --display-name="Cloud Function Errors" \
    --condition-display-name="Error rate > 1%" \
    --condition-threshold-value=1 \
    --condition-threshold-duration=300s
```

## Cost Optimization Tips

1. **Use Dataproc Serverless** instead of persistent clusters (already configured)
2. **Enable lifecycle policies** on Cloud Storage (already configured)
3. **Partition BigQuery tables** by date (already configured)
4. **Set table expiration** for temporary data (already configured)
5. **Use preemptible VMs** for non-critical workloads
6. **Monitor costs** in Cloud Console:
   ```bash
   open "https://console.cloud.google.com/billing"
   ```

## Troubleshooting

### Terraform Issues

```bash
# Reset Terraform state
rm -rf terraform/.terraform
terraform init

# View current state
terraform show

# Import existing resource
terraform import google_storage_bucket.raw_data ${GCP_PROJECT_ID}-raw-data-dev
```

### Permission Issues

```bash
# Check current permissions
gcloud projects get-iam-policy $GCP_PROJECT_ID

# Add missing role
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="serviceAccount:SERVICE_ACCOUNT_EMAIL" \
    --role="roles/ROLE_NAME"
```

### Function Deployment Issues

```bash
# Check function status
gcloud functions describe data-ingestion-dev --region=$GCP_REGION --gen2

# View function logs
gcloud functions logs read data-ingestion-dev --region=$GCP_REGION --limit=50
```

### Cloud Function 404 Error

If you get a 404 error when testing the function:

**Cause**: Function code wasn't uploaded before Terraform deployment.

**Solution**:
```bash
# 1. Delete existing functions
gcloud functions delete data-ingestion-dev --gen2 --region=$GCP_REGION --quiet
gcloud functions delete pubsub-processor-dev --gen2 --region=$GCP_REGION --quiet

# 2. Make sure function code is uploaded
gsutil ls gs://${GCP_PROJECT_ID}-function-source-dev/cloud-functions/
# Should show: data-ingestion.zip and pubsub-processor.zip

# 3. If missing, upload them:
cd functions/data-ingestion
zip -r data-ingestion.zip main.py requirements.txt
gsutil cp data-ingestion.zip gs://${GCP_PROJECT_ID}-function-source-dev/cloud-functions/

cd ../pubsub-processor
zip -r pubsub-processor.zip main.py requirements.txt
gsutil cp pubsub-processor.zip gs://${GCP_PROJECT_ID}-function-source-dev/cloud-functions/

# 4. Redeploy with Terraform
cd ../../terraform
terraform apply
```

## Cleanup

To destroy all resources:

```bash
# Using cleanup script
./scripts/cleanup.sh dev

# Or manually with Terraform
cd terraform
terraform destroy
```

## Next Steps

1. **Customize the PySpark job** for your data transformation needs
2. **Add data validation** rules in Cloud Functions
3. **Set up monitoring and alerting**
4. **Configure VPC** for network isolation
5. **Implement CI/CD** for automatic deployments
6. **Add data quality checks** in Airflow DAGs
7. **Configure backup and disaster recovery**

## Support

- GCP Documentation: https://cloud.google.com/docs
- Terraform GCP Provider: https://registry.terraform.io/providers/hashicorp/google/latest/docs
- Dataproc Serverless: https://cloud.google.com/dataproc-serverless/docs

## Security Best Practices

1. ✅ Use service accounts with minimal permissions
2. ✅ Enable VPC Service Controls (not included, add if needed)
3. ✅ Encrypt data at rest (enabled by default)
4. ✅ Use Secret Manager for credentials
5. ✅ Enable audit logging
6. ✅ Implement network policies
7. ✅ Regular security scans (included in GitHub Actions)
