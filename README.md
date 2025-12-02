# Few Considerations
**1. Traditional Spark Architecture - The typical high-volume data processing stack includes:**
* PySpark on EMR/Databricks for distributed processing
* Kafka as streaming data source
* HDFS/Hive for intermediate storage
* PostgreSQL/Data Warehouse for final storage
* This is indeed costly due to persistent cluster costs.

**2. AWS Cost-Optimized Architecture - Mostly Correct, with Adjustments:**

✅ Better approach:

* AWS Glue (serverless Spark) - not invoking Lambdas, but running PySpark ETL jobs directly
* Lambda - for lightweight transformations only (10GB memory, 15min timeout limits)
* S3 - intermediate storage ✓
* Kinesis/Kafka - streaming source
* Redshift/Athena - data warehouse (Databricks/Snowflake also work but add cost)
* ⚠️ Note: Glue jobs don't invoke Lambdas for heavy ETL - Glue itself runs PySpark jobs serverlessly. Use Lambdas only for orchestration or light transformations.

**3. Azure Architecture**

* Azure Data Factory (ADF) - orchestration
* Azure Functions - lightweight processing
* Databricks/Synapse Analytics - Spark processing
* Blob Storage/ADLS Gen2 - intermediate storage
* Synapse/Databricks/Snowflake - data warehouse

# GCP Cost-Effective Data Pipeline

A serverless, cost-optimized data processing pipeline on Google Cloud Platform using Terraform and GitHub Actions.

## 🏗️ Architecture Overview

### GCP Services Comparison

| AWS | Azure | GCP | Purpose |
|-----|-------|-----|---------|
| Kinesis/Kafka | Event Hubs | **Pub/Sub** | Real-time streaming |
| Lambda | Functions | **Cloud Functions** | Lightweight processing |
| Glue | Synapse Spark | **Dataproc Serverless** | PySpark ETL jobs |
| Step Functions | Logic Apps | **Cloud Composer (Airflow)** | Workflow orchestration |
| S3 | Blob Storage | **Cloud Storage** | Object storage |
| Athena | Synapse SQL | **BigQuery** | Data warehouse |
| Glue Data Catalog | Purview | **Data Catalog** | Metadata management |

### Pipeline Flow

```
Data Sources → Pub/Sub → Cloud Functions (optional) → Dataproc Serverless (PySpark)
                                                              ↓
                                                    Cloud Storage (GCS)
                                                              ↓
                                                         BigQuery
                                                              ↓
                                    Cloud Composer orchestrates the entire flow
```

## 💰 Cost Optimization Strategy

### Why This is Cheaper Than EMR/Spark Clusters:

1. **Dataproc Serverless** - Pay only for job execution time (per second billing)
2. **Cloud Functions** - First 2M invocations free, then $0.40/M
3. **Pub/Sub** - First 10GB free, then $40/TB
4. **BigQuery** - First 1TB queries free monthly, $6.25/TB after
5. **Cloud Storage** - $0.020/GB for standard storage
6. **No persistent clusters** - Resources auto-scale and shut down

### Cost Estimate (Processing 1TB/month):
- Pub/Sub: ~$40
- Cloud Functions: ~$10
- Dataproc Serverless: ~$100-150 (vs $500-1000 for persistent EMR)
- BigQuery Storage: ~$20
- Cloud Storage: ~$20
- **Total: ~$200-250/month** vs $1000+ for EMR

## 🚀 Quick Start

### Prerequisites

1. **GCP Account** with billing enabled
2. **Service Account** with appropriate permissions
3. **Terraform** >= 1.0
4. **gcloud CLI** installed and authenticated

### Local Setup

```bash
# Clone the repository
git clone <your-repo>
cd gcp-data-pipeline

# Set GCP project
export GCP_PROJECT_ID="your-project-id"
export GCP_REGION="us-central1"

# Initialize Terraform
cd terraform
terraform init

# Plan deployment
terraform plan -var="project_id=${GCP_PROJECT_ID}" -var="region=${GCP_REGION}"

# Apply (create resources)
terraform apply -var="project_id=${GCP_PROJECT_ID}" -var="region=${GCP_REGION}"
```

### GitHub Actions Deployment

1. **Set up GCP Service Account**:
```bash
gcloud iam service-accounts create github-actions-sa \
    --display-name="GitHub Actions Service Account"

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
    --member="serviceAccount:github-actions-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/editor"
```

2. **Generate Key**:
```bash
gcloud iam service-accounts keys create key.json \
    --iam-account=github-actions-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com
```

3. **Add GitHub Secrets**:
   - `GCP_PROJECT_ID`: Your GCP project ID
   - `GCP_SA_KEY`: Contents of key.json (base64 encoded)
   - `GCP_REGION`: Your preferred region

4. **Push to GitHub** - Actions will automatically run

## 📁 Project Structure

```
gcp-data-pipeline/
├── terraform/
│   ├── main.tf                 # Main Terraform configuration
│   ├── variables.tf            # Variable definitions
│   ├── outputs.tf              # Output values
│   ├── modules/
│   │   ├── pubsub/            # Pub/Sub topics and subscriptions
│   │   ├── cloud-functions/   # Cloud Functions
│   │   ├── dataproc/          # Dataproc Serverless
│   │   ├── storage/           # Cloud Storage buckets
│   │   ├── bigquery/          # BigQuery datasets and tables
│   │   └── composer/          # Cloud Composer (Airflow)
│   └── backend.tf             # Terraform state backend
├── functions/
│   ├── data-ingestion/        # Cloud Function for data ingestion
│   └── data-validation/       # Cloud Function for validation
├── pyspark-jobs/
│   ├── etl_transform.py       # Main ETL transformation job
│   └── requirements.txt       # Python dependencies
├── airflow-dags/
│   └── data_pipeline_dag.py   # Airflow orchestration DAG
├── .github/
│   └── workflows/
│       └── deploy.yml         # GitHub Actions CI/CD
└── README.md
```

## 🔧 Components Explained

### 1. Data Ingestion (Pub/Sub + Cloud Functions)
- **Pub/Sub** receives streaming data (replaces Kafka)
- **Cloud Function** validates and routes messages
- Triggers downstream processing

### 2. Processing (Dataproc Serverless)
- Runs **PySpark jobs** without managing clusters
- Auto-scales based on workload
- Processes data from GCS/Pub/Sub
- Writes to BigQuery or GCS

### 3. Storage Layers
- **Cloud Storage**: Raw data, intermediate results
- **BigQuery**: Data warehouse for analytics
- Lifecycle policies auto-delete old data

### 4. Orchestration (Cloud Composer)
- **Apache Airflow** managed service
- Schedules and monitors pipelines
- Handles dependencies and retries

## 🔐 Security Best Practices

1. **Service Accounts**: Principle of least privilege
2. **VPC Service Controls**: Network isolation
3. **Encryption**: At rest (default) and in transit
4. **Secret Manager**: Store credentials
5. **IAM Policies**: Fine-grained access control

## 📊 Monitoring & Observability

- **Cloud Monitoring**: Metrics and alerts
- **Cloud Logging**: Centralized logs
- **Cloud Trace**: Distributed tracing
- **BigQuery**: Query performance metrics

## 🔄 CI/CD Pipeline

GitHub Actions workflow:
1. Validate Terraform syntax
2. Run security scans
3. Plan infrastructure changes
4. Apply on merge to main
5. Deploy Cloud Functions
6. Upload PySpark jobs to GCS
7. Update Airflow DAGs

## 📈 Scaling Considerations

- **Pub/Sub**: Automatically scales to millions of messages/sec
- **Dataproc Serverless**: Specify min/max workers in Terraform
- **BigQuery**: Automatically scales, consider partitioning large tables
- **Cloud Functions**: Increase memory/timeout for heavy workloads

## 🧪 Testing

### Quick Test
```bash
# Run comprehensive test suite
./scripts/test.sh dev
```

### Generate Sample Streaming Data

The pipeline includes a realistic data generator for testing:

```bash
# Install dependencies
pip install -r scripts/requirements.txt

# Generate 100 sample transactions
python scripts/generate_sample_data.py \
    --function-url YOUR_CLOUD_FUNCTION_URL \
    --type transaction \
    --count 100

# Stream data continuously at 10 events/sec
python scripts/generate_sample_data.py \
    --function-url YOUR_CLOUD_FUNCTION_URL \
    --stream \
    --rate 10 \
    --duration 60 \
    --type mixed
```

**Available data types:**
- `transaction` - E-commerce transactions
- `user_activity` - User behavior events
- `iot_sensor` - IoT device readings
- `application_log` - Service logs
- `mixed` - Combination of all types

See `sample-data/README.md` for detailed usage examples.

### Manual Testing

```bash
# Test Cloud Function with curl
FUNCTION_URL="your-function-url"
curl -X POST "$FUNCTION_URL" \
    -H "Content-Type: application/json" \
    -d '{"data_type": "transaction", "payload": {"amount": 99.99}}'

# Test PySpark job locally (requires Spark)
cd pyspark-jobs
spark-submit etl_transform.py --project-id YOUR_PROJECT

# Validate Terraform
cd terraform
terraform validate
terraform fmt -check
```

## 🆘 Troubleshooting

### Common Issues

1. **Quota Exceeded**: Request quota increase in GCP Console
2. **Permission Denied**: Check service account IAM roles
3. **Dataproc Job Fails**: Check logs in Cloud Logging
4. **BigQuery Costs High**: Implement partitioning and clustering

## 📚 Additional Resources

- [GCP Data Analytics Documentation](https://cloud.google.com/solutions/data-analytics)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Dataproc Serverless Guide](https://cloud.google.com/dataproc-serverless/docs)
- [BigQuery Best Practices](https://cloud.google.com/bigquery/docs/best-practices)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test
4. Submit a pull request

## 📄 License

MIT License - See LICENSE file for details
