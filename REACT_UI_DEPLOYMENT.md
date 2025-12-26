# React UI Deployment Guide

This guide covers deploying the React-based data ingestion UI to Google Cloud Run.

## Architecture

```
┌─────────────────┐
│  User Browser   │
└────────┬────────┘
         │ HTTPS
         ▼
┌─────────────────────────────┐
│   Cloud Run (React App)     │
│   - React SPA               │
│   - Vite build              │
│   - Node.js server          │
└────────┬────────────────────┘
         │ HTTPS/CORS
         ▼
┌─────────────────────────────┐
│  Cloud Function (Gen2)      │
│  - data-ingestion           │
│  - CORS enabled             │
└────────┬────────────────────┘
         │ Pub/Sub
         ▼
┌─────────────────────────────┐
│   Processing Pipeline       │
└─────────────────────────────┘
```

## Prerequisites

1. GCP project with billing enabled
2. Cloud Run API enabled
3. Data ingestion Cloud Function deployed
4. Docker (optional, for local testing)
5. Node.js 18+ (for local development)

## Deployment Methods

### Method 1: Using Terraform (Recommended)

This is the infrastructure-as-code approach that ensures consistency.

**Step 1: Configure Terraform variables**

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
project_id  = "your-project-id"
region      = "us-central1"
environment = "dev"
enable_ui   = true
ui_allow_unauthenticated = true
```

**Step 2: Build and push Docker image**

```bash
# Navigate to react-app directory
cd ../react-app

# Set variables
export PROJECT_ID="your-project-id"
export IMAGE_NAME="gcr.io/${PROJECT_ID}/data-pipeline-ui:latest"

# Build the image
docker build -t $IMAGE_NAME .

# Push to Google Container Registry
docker push $IMAGE_NAME
```

**Step 3: Deploy with Terraform**

```bash
cd ../terraform
terraform apply
```

Terraform will:
- Create the Cloud Run service
- Configure environment variables
- Set up IAM permissions
- Output the service URL

**Step 4: Get the URL**

```bash
terraform output ui_service_url
```

### Method 2: Using gcloud CLI (Quick Deploy)

Deploy directly from source code without building Docker images locally.

```bash
cd react-app

# Set variables
export PROJECT_ID="your-project-id"
export REGION="us-central1"
export FUNCTION_URL="https://${REGION}-${PROJECT_ID}.cloudfunctions.net/data-ingestion-function-dev"

# Deploy from source
gcloud run deploy data-pipeline-ui-dev \
  --source . \
  --platform managed \
  --region ${REGION} \
  --allow-unauthenticated \
  --set-env-vars VITE_API_URL=${FUNCTION_URL} \
  --memory 512Mi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 10 \
  --project ${PROJECT_ID}
```

### Method 3: Using Deployment Script

We provide a convenient script that automates the deployment.

```bash
# From project root
./scripts/deploy-ui.sh dev

# For production
./scripts/deploy-ui.sh prod
```

The script will:
1. Detect the Cloud Function URL automatically
2. Build and deploy to Cloud Run
3. Display the service URL
4. Open the browser automatically

## Environment Variables

The React app requires the following environment variable:

| Variable | Description | Example |
|----------|-------------|---------|
| `VITE_API_URL` | Cloud Function endpoint URL | `https://us-central1-project.cloudfunctions.net/data-ingestion-function-dev` |

**Setting environment variables:**

**For Cloud Run (via Terraform):**
```hcl
# Already configured in terraform/modules/cloud-run/main.tf
env {
  name  = "VITE_API_URL"
  value = var.ingestion_function_url
}
```

**For Cloud Run (via gcloud):**
```bash
gcloud run services update data-pipeline-ui-dev \
  --region us-central1 \
  --update-env-vars VITE_API_URL=https://your-function-url
```

**For local development:**
```bash
cd react-app
cp .env.example .env
# Edit .env and set VITE_API_URL
```

## Local Development

### Run Locally with Vite

```bash
cd react-app

# Install dependencies
npm install

# Create .env file
cp .env.example .env
# Edit .env with your Cloud Function URL

# Start development server
npm run dev

# Open http://localhost:3000
```

### Run Locally with Docker

```bash
cd react-app

# Build image
docker build -t data-pipeline-ui:local .

# Run container
docker run -p 8080:8080 \
  -e VITE_API_URL=https://your-function-url \
  data-pipeline-ui:local

# Open http://localhost:8080
```

## CORS Configuration

The Cloud Function must allow CORS requests from the React app. This is already configured in `functions/data-ingestion/main.py`:

```python
headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Max-Age': '3600'
}
```

**For production**, restrict the origin:
```python
headers = {
    'Access-Control-Allow-Origin': 'https://your-cloud-run-url.run.app',
    # ... other headers
}
```

## Security Considerations

### For Development

```bash
# Allow unauthenticated access (current setup)
gcloud run services add-iam-policy-binding data-pipeline-ui-dev \
  --region=us-central1 \
  --member="allUsers" \
  --role="roles/run.invoker"
```

### For Production

**Option 1: Identity-Aware Proxy (IAP)**

Enable IAP for user authentication via Google accounts.

**Option 2: Cloud Run Authentication**

Remove public access and require authentication:

```bash
# Remove public access
gcloud run services remove-iam-policy-binding data-pipeline-ui-prod \
  --region=us-central1 \
  --member="allUsers" \
  --role="roles/run.invoker"

# Add specific users/service accounts
gcloud run services add-iam-policy-binding data-pipeline-ui-prod \
  --region=us-central1 \
  --member="user:email@example.com" \
  --role="roles/run.invoker"
```

**Option 3: API Key in Cloud Function**

Add API key validation in the Cloud Function.

## Monitoring and Logging

### View Logs

```bash
# Cloud Run logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=data-pipeline-ui-dev" \
  --limit 50 \
  --format json

# Or in Cloud Console
# https://console.cloud.google.com/run/detail/REGION/SERVICE_NAME/logs
```

### Metrics

Cloud Run automatically provides metrics:
- Request count
- Request latency
- Container CPU utilization
- Container memory utilization
- Container instance count

Access at: Console → Cloud Run → Select Service → Metrics

### Set Up Alerts

```bash
# Example: Alert on high error rate
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="Cloud Run Error Rate Alert" \
  --condition-threshold-value=5 \
  --condition-threshold-duration=300s
```

## Troubleshooting

### Issue: CORS errors in browser

**Solution:** Verify Cloud Function has CORS headers enabled.

```bash
# Test CORS
curl -X OPTIONS https://your-function-url \
  -H "Origin: https://your-cloud-run-url.run.app" \
  -H "Access-Control-Request-Method: POST" \
  -v
```

### Issue: Service won't start

**Solution:** Check logs for startup errors.

```bash
gcloud logging read "resource.type=cloud_run_revision" --limit 20
```

### Issue: 404 on routes

**Solution:** Vite build may have issues with routing. Ensure `index.html` is served for all routes.

### Issue: Environment variables not set

**Solution:** Rebuild and redeploy with correct env vars.

```bash
gcloud run services update data-pipeline-ui-dev \
  --update-env-vars VITE_API_URL=https://correct-url
```

## Cost Optimization

Cloud Run pricing:
- **CPU allocation**: Billed only during request handling
- **Memory**: 512 Mi (default)
- **Requests**: First 2 million free per month
- **Pricing**: ~$0.00002400 per request

**Estimated monthly cost for 100K requests/month**: ~$2-5

**Optimization tips:**
1. Set `min-instances=0` to scale to zero
2. Use appropriate memory allocation (512Mi is sufficient)
3. Enable request caching if possible
4. Consider Cloud CDN for static assets

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy UI to Cloud Run

on:
  push:
    branches: [main]
    paths:
      - 'react-app/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}
      
      - name: Deploy to Cloud Run
        run: |
          cd react-app
          gcloud run deploy data-pipeline-ui-prod \
            --source . \
            --region us-central1 \
            --allow-unauthenticated
```

## Testing the Deployment

### Manual Test

1. Open the Cloud Run URL in browser
2. Fill in the form:
   - Data Type: `user_event`
   - User ID: `test_user_123`
   - Event Name: `page_view`
   - Properties: `{"page": "/home"}`
3. Click "Send Data"
4. Verify success response

### Automated Test

```bash
# Get the URL
UI_URL=$(gcloud run services describe data-pipeline-ui-dev \
  --region=us-central1 --format='value(status.url)')

# Test if it's accessible
curl -I $UI_URL

# Should return 200 OK
```

## Updating the Application

### Update Code

```bash
cd react-app

# Make changes to src/App.jsx or other files

# Redeploy
gcloud run deploy data-pipeline-ui-dev \
  --source . \
  --region us-central1
```

### Update Environment Variables Only

```bash
gcloud run services update data-pipeline-ui-dev \
  --region us-central1 \
  --update-env-vars VITE_API_URL=https://new-function-url
```

## Rollback

```bash
# List revisions
gcloud run revisions list --service=data-pipeline-ui-dev --region=us-central1

# Rollback to previous revision
gcloud run services update-traffic data-pipeline-ui-dev \
  --region=us-central1 \
  --to-revisions=REVISION_NAME=100
```

## Additional Resources

- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [React Deployment Best Practices](https://create-react-app.dev/docs/deployment/)
- [Vite Production Build](https://vitejs.dev/guide/build.html)
- [GCP CORS Configuration](https://cloud.google.com/functions/docs/writing/http#cors_preflight_requests)
