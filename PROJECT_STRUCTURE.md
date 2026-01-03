# GCP Data Pipeline - Project Structure

```
gcp-data-pipeline/
├── README.md                          # Main documentation
├── SETUP.md                           # Detailed setup guide
├── ARCHITECTURE.md                    # Architecture diagrams
├── COST_ANALYSIS.md                   # Cost breakdown and optimization
├── QUICK_REFERENCE.md                 # Command cheatsheet
├── SUMMARY.md                         # Complete solution summary
├── LICENSE                            # MIT License
├── .gitignore                         # Git ignore patterns
│
├── terraform/                         # Infrastructure as Code
│   ├── main.tf                        # Main Terraform configuration
│   ├── variables.tf                   # Variable definitions
│   ├── outputs.tf                     # Output values
│   ├── terraform.tfvars.example       # Example variables file
│   │
│   └── modules/                       # Terraform modules
│       ├── storage/                   # Cloud Storage buckets
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       │
│       ├── pubsub/                    # Pub/Sub topics & subscriptions
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       │
│       ├── bigquery/                  # BigQuery datasets & tables
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       │
│       ├── cloud-functions/           # Cloud Functions
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       │
│       ├── dataproc/                  # Dataproc Serverless config
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       │
│       ├── cloud-run/                 # Cloud Run for React UI
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       │
│       ├── spanner/                   # Cloud Spanner (optional)
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       │
│       └── composer/                  # Cloud Composer (Airflow)
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
│
├── react-app/                         # React UI for data ingestion
│   ├── src/                           # React source code
│   │   ├── App.jsx                    # Main component
│   │   ├── App.css                    # Styles
│   │   └── main.jsx                   # Entry point
│   ├── Dockerfile                     # Container configuration
│   ├── package.json                   # NPM dependencies
│   ├── vite.config.js                 # Vite build config
│   ├── .env.example                   # Environment variables template
│   └── README.md                      # UI documentation
│
├── functions/                         # Cloud Function source code
│   ├── data-ingestion/                # HTTP-triggered ingestion
│   │   ├── main.py                    # Function code
│   │   └── requirements.txt           # Python dependencies
│   │
│   └── pubsub-processor/              # Event-triggered processing
│       ├── main.py                    # Function code
│       └── requirements.txt           # Python dependencies
│
├── pyspark-jobs/                      # PySpark ETL jobs
│   ├── etl_transform.py               # Main ETL job
│   └── requirements.txt               # Python dependencies
│
├── airflow-dags/                      # Airflow DAGs
│   └── data_pipeline_dag.py           # Main orchestration DAG
│
├── scripts/                           # Utility scripts
│   ├── deploy.sh                      # One-command deployment
│   ├── test.sh                        # Testing script
│   └── cleanup.sh                     # Resource cleanup
│
└── .github/                           # GitHub Actions CI/CD
    └── workflows/
        └── deploy.yml                 # Deployment workflow
```

## File Descriptions

### Documentation Files

| File | Purpose | When to Use |
|------|---------|-------------|
| `README.md` | Overview, quick start, architecture | First file to read |
| `SETUP.md` | Detailed setup instructions | When deploying for first time |
| `ARCHITECTURE.md` | System design and diagrams | Understanding the system |
| `COST_ANALYSIS.md` | Cost estimates and optimization | Budget planning |
| `QUICK_REFERENCE.md` | Command cheatsheet | Daily operations |
| `SUMMARY.md` | Complete solution overview | Executive summary |

### Infrastructure (Terraform)

| File | Purpose | Modify When |
|------|---------|-------------|
| `terraform/main.tf` | Root configuration | Adding new resources |
| `terraform/variables.tf` | Input variables | Changing defaults |
| `terraform/outputs.tf` | Output values | Need new outputs |
| `terraform/terraform.tfvars.example` | Example config | Sharing template |
| `terraform/modules/*/` | Resource modules | Customizing components |

### Application Code

| File | Purpose | Modify When |
|------|---------|-------------|
| `react-app/src/App.jsx` | React UI main component | Changing UI functionality |
| `react-app/Dockerfile` | Cloud Run container config | Changing deployment |
| `functions/data-ingestion/main.py` | HTTP data ingestion | Changing ingestion logic |
| `functions/pubsub-processor/main.py` | Pub/Sub processing | Changing validation rules |
| `pyspark-jobs/etl_transform.py` | PySpark ETL | Changing transformations |
| `airflow-dags/data_pipeline_dag.py` | Airflow orchestration | Changing schedule/workflow |

### Operational Scripts

| File | Purpose | When to Use |
|------|---------|-------------|
| `scripts/deploy.sh` | Deploy everything | Initial setup, updates |
| `scripts/test.sh` | Test components | After deployment, debugging |
| `scripts/cleanup.sh` | Delete resources | Teardown, cleanup |

### CI/CD

| File | Purpose | When to Use |
|------|---------|-------------|
| `.github/workflows/deploy.yml` | GitHub Actions | Automated deployments |

## Lines of Code

```
Configuration (Terraform):     ~1,200 lines
Application Code (Python):     ~800 lines
Documentation (Markdown):      ~1,500 lines
Scripts (Bash):                ~200 lines
CI/CD (YAML):                  ~250 lines
─────────────────────────────────────────
TOTAL:                         ~3,950 lines
```

## Module Dependencies

```
terraform/main.tf
    ├── modules/storage          (4 buckets)
    ├── modules/pubsub           (4 topics, 4 subscriptions)
    ├── modules/bigquery         (1 dataset, 3 tables, 1 view)
    ├── modules/spanner          (optional - distributed database)
    │       └── instance, database, tables, IAM
    ├── modules/cloud-functions  (2 functions)
    │       └── depends on: storage, pubsub, spanner (optional)
    ├── modules/dataproc         (serverless config)
    │       └── depends on: storage
    └── modules/composer         (optional)
            └── depends on: storage, pubsub, bigquery
```

## Data Flow Through Files

```
1. Data Ingestion:
   HTTP Request → functions/data-ingestion/main.py → Pub/Sub

2. Event Processing:
   Pub/Sub → functions/pubsub-processor/main.py → Cloud Storage

3. Batch Processing:
   airflow-dags/data_pipeline_dag.py (schedules)
       → pyspark-jobs/etl_transform.py (processes)
       → BigQuery (stores)

4. Infrastructure:
   terraform/main.tf (provisions)
       → All modules (creates resources)
       → GCP (deployed)

5. CI/CD:
   GitHub Push → .github/workflows/deploy.yml (runs)
       → terraform/ (deploys infrastructure)
       → functions/ (deploys functions)
       → pyspark-jobs/ (uploads jobs)
```

## Configuration Files

### Terraform Variables (terraform.tfvars)
```hcl
project_id  = "your-project-id"
region      = "us-central1"
environment = "dev"
enable_composer = false
```

### Environment Variables (.env or shell)
```bash
GCP_PROJECT_ID="your-project-id"
GCP_REGION="us-central1"
ENVIRONMENT="dev"
```

### GitHub Secrets
```
GCP_PROJECT_ID    # Your GCP project ID
GCP_SA_KEY        # Service account key (base64)
GCP_REGION        # Deployment region
```

## Resource Naming Convention

All resources follow this pattern:
```
{project_id}-{resource_type}-{environment}
```

Examples:
- `my-project-raw-data-dev` (Cloud Storage bucket)
- `data-pipeline-sa-dev` (Service account)
- `raw-data-topic-dev` (Pub/Sub topic)
- `data_warehouse_dev` (BigQuery dataset)

## Getting Started Checklist

1. ✅ Clone/download this repository
2. ✅ Review `README.md` for overview
3. ✅ Read `SETUP.md` for detailed instructions
4. ✅ Set environment variables
5. ✅ Copy `terraform.tfvars.example` to `terraform.tfvars`
6. ✅ Update `terraform.tfvars` with your values
7. ✅ Run `terraform init` and `terraform apply`
8. ✅ Run `./scripts/deploy.sh dev`
9. ✅ Run `./scripts/test.sh dev`
10. ✅ Check `QUICK_REFERENCE.md` for commands

## Customization Points

### High Priority (Likely to Change)
- ✏️ `pyspark-jobs/etl_transform.py` - Your transformation logic
- ✏️ `terraform/terraform.tfvars` - Your project settings
- ✏️ `functions/data-ingestion/main.py` - Your validation rules

### Medium Priority (May Change)
- ✏️ `terraform/modules/bigquery/main.tf` - Your table schema
- ✏️ `airflow-dags/data_pipeline_dag.py` - Your schedule
- ✏️ `terraform/variables.tf` - Resource sizing

### Low Priority (Usually Don't Change)
- 📌 `terraform/modules/*/main.tf` - Infrastructure setup
- 📌 `.github/workflows/deploy.yml` - CI/CD pipeline
- 📌 `scripts/*.sh` - Operational scripts

## Total Resource Count

When fully deployed, you'll have:

- **Cloud Storage**: 4-5 buckets
- **Pub/Sub**: 4 topics, 4 subscriptions
- **BigQuery**: 1 dataset, 3 tables, 1 view
- **Cloud Functions**: 2 functions
- **Cloud Spanner**: 1 instance, 1 database, 3 tables (optional)
- **IAM**: 1 service account + roles
- **Cloud Scheduler**: 1 job
- **Cloud Composer**: 1 environment (optional)
- **Cloud Run**: 1 service (React UI)
- **Monitoring**: Automatic dashboards and logs

**Total: ~25-30 GCP resources**

## Maintenance Files

Files you'll interact with regularly:

**Daily:**
- `QUICK_REFERENCE.md` - Command reference
- CloudConsole logs and monitoring

**Weekly:**
- `pyspark-jobs/etl_transform.py` - Update transformations
- `airflow-dags/data_pipeline_dag.py` - Adjust schedules

**Monthly:**
- `COST_ANALYSIS.md` - Review costs
- `terraform/variables.tf` - Optimize resources

**Quarterly:**
- `ARCHITECTURE.md` - Review architecture
- All documentation - Keep up to date
