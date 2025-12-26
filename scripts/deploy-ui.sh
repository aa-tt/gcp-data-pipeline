#!/bin/bash

# Deploy React UI to Google Cloud Run
# Usage: ./deploy-ui.sh [environment]

set -e

# Configuration
ENVIRONMENT=${1:-dev}
PROJECT_ID=${GCP_PROJECT_ID}
REGION=${GCP_REGION:-us-central1}
SERVICE_NAME="data-pipeline-ui-${ENVIRONMENT}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Deploying React UI to Cloud Run${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "Environment: ${YELLOW}${ENVIRONMENT}${NC}"
echo -e "Project ID:  ${YELLOW}${PROJECT_ID}${NC}"
echo -e "Region:      ${YELLOW}${REGION}${NC}"
echo -e "Service:     ${YELLOW}${SERVICE_NAME}${NC}"
echo ""

# Check if required variables are set
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: GCP_PROJECT_ID is not set${NC}"
    exit 1
fi

# Get the Cloud Function URL
echo -e "${GREEN}[1/5] Getting Cloud Function URL...${NC}"
FUNCTION_NAME="data-ingestion-function-${ENVIRONMENT}"
FUNCTION_URL=$(gcloud functions describe $FUNCTION_NAME \
    --region=$REGION \
    --gen2 \
    --format="value(serviceConfig.uri)" 2>/dev/null || echo "")

if [ -z "$FUNCTION_URL" ]; then
    echo -e "${YELLOW}Warning: Could not find Cloud Function URL${NC}"
    echo -e "${YELLOW}Using placeholder. Update VITE_API_URL after deployment.${NC}"
    FUNCTION_URL="https://${REGION}-${PROJECT_ID}.cloudfunctions.net/${FUNCTION_NAME}"
fi

echo -e "Function URL: ${YELLOW}${FUNCTION_URL}${NC}"

# Navigate to react-app directory
cd "$(dirname "$0")/../react-app"

# Build the Docker image (optional, Cloud Run can build from source)
echo -e "${GREEN}[2/5] Building Docker image (optional)...${NC}"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}:latest"

# You can skip this step and let Cloud Run build from source
# docker build -t $IMAGE_NAME .
# docker push $IMAGE_NAME

# Deploy to Cloud Run from source
echo -e "${GREEN}[3/5] Deploying to Cloud Run...${NC}"
gcloud run deploy $SERVICE_NAME \
    --source . \
    --platform managed \
    --region $REGION \
    --allow-unauthenticated \
    --set-env-vars VITE_API_URL=$FUNCTION_URL \
    --set-env-vars NODE_ENV=production \
    --set-build-env-vars VITE_API_URL=$FUNCTION_URL \
    --memory 512Mi \
    --cpu 1 \
    --min-instances 0 \
    --max-instances 10 \
    --port 8080 \
    --project $PROJECT_ID

# Get the service URL
echo -e "${GREEN}[4/5] Getting service URL...${NC}"
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME \
    --region $REGION \
    --format 'value(status.url)' \
    --project $PROJECT_ID)

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}✓ Deployment Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "React UI URL: ${YELLOW}${SERVICE_URL}${NC}"
echo -e "API Endpoint: ${YELLOW}${FUNCTION_URL}${NC}"
echo ""
echo -e "${GREEN}[5/5] Testing the deployment...${NC}"
echo -e "Opening browser in 3 seconds..."
sleep 3

# Try to open in browser
if command -v open &> /dev/null; then
    open $SERVICE_URL
elif command -v xdg-open &> /dev/null; then
    xdg-open $SERVICE_URL
else
    echo -e "${YELLOW}Please open the URL manually: ${SERVICE_URL}${NC}"
fi

echo ""
echo -e "${GREEN}Next steps:${NC}"
echo -e "1. Visit ${YELLOW}${SERVICE_URL}${NC} to test the UI"
echo -e "2. Fill in the form and submit test data"
echo -e "3. Check Cloud Logging for ingestion logs"
echo -e "4. Query BigQuery to verify data arrived"
echo ""
