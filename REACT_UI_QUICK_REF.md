# React UI - Quick Reference

## 🚀 Quick Deploy

```bash
# One-command deployment
./scripts/deploy-ui.sh dev

# Or manually
cd react-app
gcloud run deploy data-pipeline-ui-dev \
  --source . \
  --region us-central1 \
  --allow-unauthenticated
```

## 📍 Get Service URL

```bash
gcloud run services describe data-pipeline-ui-dev \
  --region us-central1 \
  --format='value(status.url)'
```

## 🔧 Update Environment Variables

```bash
gcloud run services update data-pipeline-ui-dev \
  --region us-central1 \
  --update-env-vars VITE_API_URL=https://your-function-url
```

## 💻 Local Development

```bash
cd react-app
npm install
cp .env.example .env
# Edit .env with your Cloud Function URL
npm run dev
# Open http://localhost:3000
```

## 🐳 Docker

```bash
cd react-app
docker build -t data-pipeline-ui .
docker run -p 8080:8080 \
  -e VITE_API_URL=https://your-function-url \
  data-pipeline-ui
```

## 📊 View Logs

```bash
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=data-pipeline-ui-dev" \
  --limit 50
```

## 🧪 Test Deployment

```bash
# Get URL
UI_URL=$(gcloud run services describe data-pipeline-ui-dev \
  --region=us-central1 --format='value(status.url)')

# Test
curl -I $UI_URL
# Should return 200 OK

# Open in browser
open $UI_URL  # macOS
xdg-open $UI_URL  # Linux
```

## 🔄 Update Application

```bash
cd react-app
# Make code changes
gcloud run deploy data-pipeline-ui-dev --source . --region us-central1
```

## ⏮️ Rollback

```bash
# List revisions
gcloud run revisions list --service=data-pipeline-ui-dev --region=us-central1

# Rollback
gcloud run services update-traffic data-pipeline-ui-dev \
  --region=us-central1 \
  --to-revisions=REVISION_NAME=100
```

## 🛡️ Security (Production)

```bash
# Remove public access
gcloud run services remove-iam-policy-binding data-pipeline-ui-prod \
  --region=us-central1 \
  --member="allUsers" \
  --role="roles/run.invoker"

# Add specific user
gcloud run services add-iam-policy-binding data-pipeline-ui-prod \
  --region=us-central1 \
  --member="user:email@example.com" \
  --role="roles/run.invoker"
```

## 💰 Cost Estimate

- **Free tier**: First 2M requests/month
- **After free tier**: ~$0.000024 per request
- **100K requests/month**: ~$2-5
- **1M requests/month**: ~$20-30

## 📁 Important Files

- `react-app/src/App.jsx` - Main React component
- `react-app/Dockerfile` - Container config
- `react-app/.env.example` - Environment template
- `terraform/modules/cloud-run/` - Terraform IaC
- `scripts/deploy-ui.sh` - Deployment script

## 🔗 Useful URLs

```bash
# Cloud Console
echo "https://console.cloud.google.com/run?project=${GCP_PROJECT_ID}"

# Service Details
echo "https://console.cloud.google.com/run/detail/us-central1/data-pipeline-ui-dev?project=${GCP_PROJECT_ID}"

# Logs
echo "https://console.cloud.google.com/logs/query?project=${GCP_PROJECT_ID}"
```

## 🆘 Troubleshooting

**CORS errors?**
- Check Cloud Function has CORS headers enabled
- Verify `Access-Control-Allow-Origin` header

**Service won't start?**
- Check logs: `gcloud logging read "resource.type=cloud_run_revision" --limit 20`
- Verify environment variables are set

**404 on routes?**
- Vite should serve index.html for all routes
- Check build output

**Can't access Function?**
- Verify VITE_API_URL is correct
- Check Function is deployed and accessible
- Test Function directly with curl

## 📚 Documentation

- Full guide: `REACT_UI_DEPLOYMENT.md`
- Setup: `SETUP.md` (Step 7)
- Architecture: `ARCHITECTURE.md`
- Project structure: `PROJECT_STRUCTURE.md`
