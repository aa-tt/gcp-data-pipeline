# Architecture Diagram

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Data Sources                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐            │
│  │   APIs   │  │  Mobile  │  │   Web    │  │  IoT     │            │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘            │
└───────┼─────────────┼─────────────┼─────────────┼──────────────────┘
        │             │             │             │
        └─────────────┴─────────────┴─────────────┘
                          │
                          ▼
        ┌─────────────────────────────────────┐
        │   Cloud Function (HTTP Trigger)     │
        │   - Validate incoming data          │
        │   - Enrich with metadata            │
        └──────────────┬──────────────────────┘
                       │
                       ▼
        ┌─────────────────────────────────────┐
        │         Pub/Sub Topic               │
        │      (Raw Data Stream)              │
        └──────────────┬──────────────────────┘
                       │
                       ▼
        ┌─────────────────────────────────────┐
        │  Cloud Function (Pub/Sub Trigger)   │
        │   - Basic transformation            │
        │   - Data validation                 │
        └──────────────┬──────────────────────┘
                       │
                       ▼
        ┌─────────────────────────────────────┐
        │      Cloud Storage (GCS)            │
        │   - Raw data bucket                 │
        │   - Partitioned by date/type        │
        └──────────────┬──────────────────────┘
                       │
                       ▼
        ┌─────────────────────────────────────┐
        │   Cloud Composer (Airflow) DAG      │
        │   - Schedule ETL jobs               │
        │   - Monitor pipeline                │
        └──────────────┬──────────────────────┘
                       │
                       ▼
        ┌─────────────────────────────────────┐
        │   Dataproc Serverless (PySpark)     │
        │   - Complex transformations         │
        │   - Aggregations                    │
        │   - Data quality checks             │
        └──────────────┬──────────────────────┘
                       │
                ┌──────┴──────┐
                ▼             ▼
    ┌───────────────┐  ┌────────────────┐
    │  BigQuery     │  │  Cloud Storage │
    │  - Analytics  │  │  - Processed   │
    │  - Warehouse  │  │  - Archive     │
    └───────┬───────┘  └────────────────┘
            │
            ▼
    ┌───────────────────┐
    │  BI Tools         │
    │  - Looker         │
    │  - Tableau        │
    │  - Power BI       │
    └───────────────────┘
```

## Detailed Component Architecture

### 1. Ingestion Layer

```
HTTP Requests ──┐
                ├──> Cloud Function ──> Pub/Sub ──> Cloud Storage
Webhook Events ─┘         │                             (Raw Data)
                          │
                          └──> BigQuery (optional)
                               (Raw Table)
```

**Components:**
- **Cloud Function (HTTP)**: Entry point for data
- **Pub/Sub**: Message queue for decoupling
- **Cloud Storage**: Durable storage for raw data

### 2. Processing Layer

```
Cloud Storage ──> Dataproc Serverless (PySpark) ──┐
      (Raw)              │                        │
                         │                        ▼
                         │                 Cloud Storage
                         │                  (Processed)
                         │
                         └──> BigQuery
                              (Analytics Tables)
```

**Components:**
- **Dataproc Serverless**: Serverless Spark for ETL
- **PySpark Jobs**: Custom transformation logic
- **Cloud Composer**: Orchestration and scheduling

### 3. Storage Layer

```
┌─────────────────────────────────────┐
│         Cloud Storage               │
├─────────────────────────────────────┤
│  raw-data/                          │
│    └─ 2024/01/15/data.json          │
│  processed-data/                    │
│    └─ 2024/01/15/analytics.parquet  │
│  staging/                           │
│    ├─ pyspark-jobs/                 │
│    └─ cloud-functions/              │
│  archive/                           │
│    └─ 2023/12/*/                    │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│         BigQuery                    │
├─────────────────────────────────────┤
│  Dataset: data_warehouse_prod       │
│    ├─ raw_data (partitioned)        │
│    ├─ analytics_data (partitioned)  │
│    ├─ daily_metrics                 │
│    └─ latest_analytics_view         │
└─────────────────────────────────────┘
```

## Data Flow Diagram

```
[Data Source]
     │
     │ HTTP POST
     ▼
[Cloud Function: Data Ingestion]
     │ Validate & Enrich
     ▼
[Pub/Sub: raw-data-topic]
     │ Publish Message
     ▼
[Cloud Function: Pub/Sub Processor]
     │ Transform
     ▼
[Cloud Storage: raw-data/]
     │ Store JSON
     ▼
[Cloud Scheduler] ── triggers ──> [Cloud Composer DAG]
     │                                   │
     │                                   │ Schedule
     ▼                                   ▼
[Dataproc Serverless]              [PySpark ETL Job]
     │                                   │
     │ Execute                           │ Read
     ▼                                   ▼
[Read from GCS]                    [Transform Data]
     │                                   │
     │                                   │ Write
     ▼                                   ▼
[Transform with Spark]            [BigQuery: analytics_data]
     │                                   │
     │                                   │ Also write
     ▼                                   ▼
[Write to BigQuery]               [GCS: processed-data/]
     │
     ▼
[BigQuery: Analytics Ready]
     │
     ▼
[BI Tools / Data Scientists]
```

## Network Architecture

```
┌──────────────────────────────────────────────────────────┐
│                   Internet                               │
└────────────────────┬─────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────┐
│               Cloud Load Balancer                        │
│                (Optional - Future)                       │
└────────────────────┬─────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────┐
│              Cloud Functions Gen2                        │
│              (Public endpoint)                           │
└────────────────────┬─────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────┐
│                    VPC Network                           │
│  ┌────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │  Pub/Sub   │  │   Dataproc   │  │   BigQuery   │    │
│  │  (Private) │  │  (Serverless)│  │   (Private)  │    │
│  └────────────┘  └──────────────┘  └──────────────┘    │
└──────────────────────────────────────────────────────────┘
```

## Security Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    IAM & Security                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Service Accounts:                                      │
│    ├─ data-pipeline-sa (main)                          │
│    ├─ terraform-sa (infrastructure)                    │
│    └─ github-actions-sa (CI/CD)                        │
│                                                         │
│  Encryption:                                            │
│    ├─ At Rest: Google-managed keys                     │
│    └─ In Transit: TLS 1.2+                             │
│                                                         │
│  Access Control:                                        │
│    ├─ Pub/Sub: IAM roles                               │
│    ├─ GCS: Bucket-level permissions                    │
│    ├─ BigQuery: Dataset-level ACL                      │
│    └─ Functions: Authenticated invocation              │
│                                                         │
│  Audit Logging:                                         │
│    ├─ Cloud Audit Logs                                 │
│    ├─ Cloud Monitoring                                 │
│    └─ Cloud Trace                                      │
└─────────────────────────────────────────────────────────┘
```

## CI/CD Architecture

```
┌──────────────────────────────────────────────────────────┐
│                      GitHub                              │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Repository: gcp-data-pipeline                     │  │
│  │    ├─ terraform/                                   │  │
│  │    ├─ functions/                                   │  │
│  │    ├─ pyspark-jobs/                                │  │
│  │    └─ .github/workflows/                           │  │
│  └────────────────┬───────────────────────────────────┘  │
└───────────────────┼──────────────────────────────────────┘
                    │ git push
                    ▼
┌──────────────────────────────────────────────────────────┐
│               GitHub Actions                             │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Workflow: Deploy Pipeline                         │  │
│  │    ├─ Validate Terraform                           │  │
│  │    ├─ Security Scan (Trivy)                        │  │
│  │    ├─ Terraform Plan/Apply                         │  │
│  │    ├─ Deploy Cloud Functions                       │  │
│  │    ├─ Upload PySpark Jobs                          │  │
│  │    └─ Run Tests                                    │  │
│  └────────────────┬───────────────────────────────────┘  │
└───────────────────┼──────────────────────────────────────┘
                    │ Deploy
                    ▼
┌──────────────────────────────────────────────────────────┐
│                   GCP Project                            │
│  ┌────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ Terraform  │  │   Functions  │  │  Dataproc    │    │
│  │ Resources  │  │   Deployed   │  │  Jobs Ready  │    │
│  └────────────┘  └──────────────┘  └──────────────┘    │
└──────────────────────────────────────────────────────────┘
```

## Monitoring & Observability

```
┌─────────────────────────────────────────────────────────┐
│              Cloud Monitoring Dashboard                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Metrics:                                               │
│    ├─ Pub/Sub message rate                             │
│    ├─ Cloud Function invocations                       │
│    ├─ Dataproc job duration                            │
│    ├─ BigQuery slot utilization                        │
│    └─ Storage usage                                    │
│                                                         │
│  Logs:                                                  │
│    ├─ Cloud Logging (centralized)                      │
│    ├─ Error logs aggregation                           │
│    └─ Audit logs                                       │
│                                                         │
│  Traces:                                                │
│    ├─ Cloud Trace (distributed tracing)                │
│    └─ Request flow visualization                       │
│                                                         │
│  Alerts:                                                │
│    ├─ Error rate > threshold                           │
│    ├─ Processing latency > SLA                         │
│    ├─ Cost > budget                                    │
│    └─ Data quality failures                            │
└─────────────────────────────────────────────────────────┘
```

## Disaster Recovery

```
Primary Region: us-central1
┌─────────────────────────────────────────┐
│  Production Resources                   │
│    ├─ Pub/Sub (multi-regional)          │
│    ├─ Cloud Storage (multi-regional)    │
│    ├─ BigQuery (multi-regional)         │
│    └─ Cloud Functions                   │
└─────────────────┬───────────────────────┘
                  │
                  │ Replication
                  ▼
Backup Region: us-east1
┌─────────────────────────────────────────┐
│  Backup Resources (Optional)            │
│    ├─ Cloud Storage (replicated)        │
│    └─ BigQuery (cross-region copy)      │
└─────────────────────────────────────────┘

RTO: < 1 hour
RPO: < 15 minutes
```

## Scaling Strategy

```
Small Scale (< 100GB/day)
   ├─ Cloud Functions: 256MB, max 10 instances
   ├─ Dataproc: 2 workers, n1-standard-4
   └─ BigQuery: On-demand pricing
   Cost: ~$100/month

Medium Scale (< 1TB/day)
   ├─ Cloud Functions: 512MB, max 100 instances
   ├─ Dataproc: 5 workers, n1-standard-8
   └─ BigQuery: On-demand or 100 slots
   Cost: ~$500/month

Large Scale (< 10TB/day)
   ├─ Cloud Functions: 1GB, max 1000 instances
   ├─ Dataproc: 20 workers, n1-highmem-8
   └─ BigQuery: 500 slots commitment
   Cost: ~$5,000/month

Enterprise Scale (> 10TB/day)
   ├─ Cloud Functions: 2GB, max 3000 instances
   ├─ Dataproc: Auto-scaling 10-100 workers
   ├─ BigQuery: 2000+ slots
   └─ VPC Service Controls
   Cost: $10,000+/month
```
