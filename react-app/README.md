# Data Pipeline UI - React Application

A React-based web interface for sending data to the GCP Data Pipeline ingestion endpoint.

## Features

- Simple form interface for data submission
- Support for multiple data types (user events, transactions, sensor data, logs)
- JSON editor for custom properties
- Real-time feedback on submission success/failure
- Sample data generator for testing
- Deployed on Google Cloud Run for serverless hosting

## Local Development

### Prerequisites

- Node.js 18+ and npm
- Access to the deployed Cloud Function URL

### Setup

1. **Install dependencies:**
```bash
npm install
```

2. **Configure environment:**
```bash
cp .env.example .env
# Edit .env and set VITE_API_URL to your Cloud Function URL
```

3. **Run development server:**
```bash
npm run dev
```

Visit http://localhost:3000

### Build for Production

```bash
npm run build
```

The built files will be in the `dist/` directory.

## Deployment to Google Cloud Run

### Using gcloud CLI

```bash
# Set variables
export PROJECT_ID="your-project-id"
export REGION="us-central1"
export SERVICE_NAME="data-pipeline-ui"

# Build and deploy
gcloud run deploy $SERVICE_NAME \
  --source . \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --set-env-vars VITE_API_URL=https://$REGION-$PROJECT_ID.cloudfunctions.net/data-ingestion-function-dev
```

### Using Docker

```bash
# Build image
docker build -t gcr.io/$PROJECT_ID/data-pipeline-ui:latest .

# Push to Container Registry
docker push gcr.io/$PROJECT_ID/data-pipeline-ui:latest

# Deploy to Cloud Run
gcloud run deploy data-pipeline-ui \
  --image gcr.io/$PROJECT_ID/data-pipeline-ui:latest \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated
```

### Using Terraform

The infrastructure is defined in `terraform/modules/cloud-run/` and deployed automatically with:

```bash
cd terraform
terraform apply
```

## Environment Variables

- `VITE_API_URL` - URL of the data-ingestion Cloud Function endpoint

## Usage

1. Select a data type from the dropdown
2. Enter user ID and event name
3. Add custom properties in JSON format
4. Click "Send Data" to submit
5. View the response from the Cloud Function

Use "Load Sample Data" to populate the form with example data.

## Architecture

```
User Browser → React App (Cloud Run) → Cloud Function → Pub/Sub → Processing Pipeline
```

The React app is deployed as a containerized application on Cloud Run, providing:
- Automatic scaling
- HTTPS endpoints
- Pay-per-use pricing
- Global CDN integration

## CORS Configuration

If you encounter CORS issues, ensure the Cloud Function has proper CORS headers configured in `functions/data-ingestion/main.py`.
