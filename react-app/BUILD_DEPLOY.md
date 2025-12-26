# Building and Deploying React UI Docker Image

## Important Note

Before running `terraform apply` with `enable_ui = true`, build and push the Docker image to Google Container Registry (GCR).

## Quick Build & Deploy

### Option 1: Build and Push Manually (Required for Terraform)

```bash
# Set your project ID
export PROJECT_ID="datapipeline-480007"

# Navigate to react-app directory
cd react-app

# Build the Docker image
docker build -t gcr.io/${PROJECT_ID}/data-pipeline-ui:latest .

# Configure Docker to use gcloud for authentication
gcloud auth configure-docker

# Push to Google Container Registry
docker push gcr.io/${PROJECT_ID}/data-pipeline-ui:latest

# Now you can run terraform apply
cd ../terraform
terraform apply
```

### Option 2: Use gcloud run deploy (No Docker Required)

Cloud Run can build the image from source directly:

```bash
cd react-app

# Deploy from source (Cloud Run builds the image for you)
gcloud run deploy data-pipeline-ui-dev \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars VITE_API_URL=https://REGION-PROJECT_ID.cloudfunctions.net/data-ingestion-function-dev
```

### Option 3: Use Cloud Build

Create a Cloud Build trigger or run manually:

```bash
cd react-app

# Submit build to Cloud Build
gcloud builds submit \
  --tag gcr.io/${PROJECT_ID}/data-pipeline-ui:latest

# Then deploy with Terraform or gcloud
```

## Terraform Workflow

The complete workflow for Terraform deployment:

```bash
# 1. Build and push image first
cd react-app
docker build -t gcr.io/${PROJECT_ID}/data-pipeline-ui:latest .
docker push gcr.io/${PROJECT_ID}/data-pipeline-ui:latest

# 2. Run Terraform
cd ../terraform
terraform init
terraform apply

# Terraform will create Cloud Run service using the pre-built image
```

## Updating the Application

When you update the React code:

```bash
# Rebuild and push new image
cd react-app
docker build -t gcr.io/${PROJECT_ID}/data-pipeline-ui:latest .
docker push gcr.io/${PROJECT_ID}/data-pipeline-ui:latest

# Force Cloud Run to use new image
gcloud run deploy data-pipeline-ui-dev \
  --image gcr.io/${PROJECT_ID}/data-pipeline-ui:latest \
  --region us-central1
```

Or simply redeploy from source:

```bash
cd react-app
gcloud run deploy data-pipeline-ui-dev \
  --source . \
  --region us-central1
```

## CI/CD with GitHub Actions

Add this to `.github/workflows/deploy.yml`:

```yaml
- name: Build and Push Docker Image
  run: |
    cd react-app
    docker build -t gcr.io/${{ secrets.GCP_PROJECT_ID }}/data-pipeline-ui:latest .
    docker push gcr.io/${{ secrets.GCP_PROJECT_ID }}/data-pipeline-ui:latest

- name: Deploy to Cloud Run
  run: |
    gcloud run deploy data-pipeline-ui-prod \
      --image gcr.io/${{ secrets.GCP_PROJECT_ID }}/data-pipeline-ui:latest \
      --region us-central1 \
      --platform managed
```

## Alternative: Deploy Without Terraform

If you prefer not to use Terraform for the UI:

1. Set `enable_ui = false` in `terraform.tfvars`
2. Deploy manually with `gcloud run deploy --source .`
3. Manage the Cloud Run service independently

## Troubleshooting

**Error: Image not found**
- Ensure you've pushed the image to GCR first
- Verify image name matches in Terraform: `gcr.io/${project_id}/data-pipeline-ui:latest`

**Error: Permission denied pushing to GCR**
```bash
gcloud auth configure-docker
gcloud auth login
```

**Error: Docker daemon not running**
- Start Docker Desktop (macOS/Windows)
- Or use `gcloud run deploy --source .` which doesn't require local Docker

## Image Tags

Use tags for version management:

```bash
# Tag with version
docker build -t gcr.io/${PROJECT_ID}/data-pipeline-ui:v1.0.0 .
docker build -t gcr.io/${PROJECT_ID}/data-pipeline-ui:latest .

# Push both
docker push gcr.io/${PROJECT_ID}/data-pipeline-ui:v1.0.0
docker push gcr.io/${PROJECT_ID}/data-pipeline-ui:latest

# Deploy specific version
gcloud run deploy data-pipeline-ui-dev \
  --image gcr.io/${PROJECT_ID}/data-pipeline-ui:v1.0.0 \
  --region us-central1
```
