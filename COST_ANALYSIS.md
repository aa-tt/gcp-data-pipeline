# GCP Data Pipeline - Cost Analysis

## Monthly Cost Estimate (Processing 1TB/month)

### Base Infrastructure (Always Running)

| Service | Configuration | Monthly Cost |
|---------|---------------|--------------|
| **Cloud Storage** | | |
| - Raw data (30 days) | ~100GB avg | $2 |
| - Processed data (60 days) | ~150GB avg | $3 |
| - Staging | ~50GB | $1 |
| - Archive | ~500GB | $1 |
| **BigQuery** | | |
| - Storage | ~200GB | $4 |
| - Queries | ~5TB scanned | $31 |
| **Pub/Sub** | | |
| - Messages | ~10GB/month | $40 |
| - Subscriptions | Standard | Included |
| **Cloud Functions** | | |
| - Invocations | ~1M/month | $2 |
| - Compute time | ~500k GB-sec | $8 |
| **TOTAL (Base)** | | **~$92** |

### Processing Costs (Pay-per-use)

| Scenario | Volume | Configuration | Cost |
|----------|--------|---------------|------|
| **Daily ETL** (30 jobs/month) | | | |
| - Dataproc Serverless | 1hr/day | n1-standard-4 (2 workers) | $120 |
| **Hourly ETL** (720 jobs/month) | | | |
| - Dataproc Serverless | 15min/hour | n1-standard-4 (2 workers) | $360 |
| **Real-time Streaming** | | | |
| - Dataproc Serverless | Always-on | n1-standard-4 (4 workers) | $1,200 |

### Optional Services (Not Included by Default)

| Service | Configuration | Monthly Cost | Notes |
|---------|---------------|--------------|-------|
| **Cloud Composer** | Small (3 nodes) | $300 | Managed Airflow |
| **Dataproc Metastore** | Developer tier | $300 | Hive metastore |
| **Cloud CDN** | With load balancer | $20 | API caching |
| **Cloud Armor** | Security policies | $10 | DDoS protection |

## Cost Comparison: GCP vs AWS vs Azure

### Scenario: 1TB data processing daily

| Component | GCP | AWS | Azure |
|-----------|-----|-----|-------|
| **Streaming Ingestion** | | | |
| Pub/Sub | $40/TB | Kinesis: $50/TB | Event Hubs: $55/TB |
| **Serverless Compute** | | | |
| Dataproc Serverless | $0.08/vCPU-hr | Glue: $0.44/DPU-hr | Synapse Spark: $0.18/vCore-hr |
| **Data Warehouse** | | | |
| BigQuery | $6.25/TB scanned | Athena: $5/TB | Synapse SQL: $5/TB |
| **Object Storage** | | | |
| Cloud Storage | $0.020/GB | S3: $0.023/GB | Blob: $0.018/GB |
| **Orchestration** | | | |
| Composer (Airflow) | $300/mo | MWAA: $300/mo | Data Factory: ~$100/mo |
| **MONTHLY TOTAL** | **$200-450** | **$300-600** | **$250-500** |

## Cost Optimization Strategies

### 1. Dataproc Serverless vs Persistent Clusters

**Traditional EMR/Dataproc Cluster:**
- 1 master (n1-standard-4): $140/month
- 3 workers (n1-standard-4): $420/month
- **Total: $560/month** (even when idle)

**Dataproc Serverless:**
- Pay only during job execution
- 30 jobs @ 1 hour each = $120/month
- **Savings: $440/month (78%)**

### 2. BigQuery Optimization

**Without Optimization:**
- Full table scans: ~10TB/month
- Cost: $62.50

**With Optimization:**
- Partitioning + clustering
- Scanned data: ~2TB/month
- Cost: $12.50
- **Savings: $50/month (80%)**

### 3. Cloud Storage Lifecycle Policies

**Without Lifecycle:**
- All data in Standard storage: $200/month

**With Lifecycle:**
- 30 days Standard: $60
- 60 days Nearline: $40
- 90+ days Archive: $10
- **Savings: $90/month (45%)**

### 4. Cloud Functions vs Cloud Run

**Cloud Functions:**
- 1M invocations, 512MB, 30s avg
- Cost: $10/month

**Cloud Run (for high traffic):**
- Same workload
- Cost: $7/month
- **Savings: $3/month (30%)**

### 5. Committed Use Discounts

**BigQuery Slots:**
- On-demand: $6.25/TB
- Flat-rate (500 slots): $2,000/month
- **Break-even: ~320TB queried/month**

**Compute Engine:**
- 1-year commitment: 25% discount
- 3-year commitment: 52% discount
- **Savings: Up to 52%**

## Real-World Cost Examples

### Example 1: Small Startup (100GB/day)

```
Daily Volume: 100GB (3TB/month)
Processing: 1 daily batch job (1 hour)

Cloud Storage:        $5
BigQuery:            $10
Pub/Sub:             $10
Dataproc Serverless: $40
Cloud Functions:      $5
--------------------------------
TOTAL:              ~$70/month
```

### Example 2: Mid-size Company (1TB/day)

```
Daily Volume: 1TB (30TB/month)
Processing: Hourly batch jobs (15 min each)

Cloud Storage:        $40
BigQuery:            $100
Pub/Sub:             $120
Dataproc Serverless: $360
Cloud Functions:      $20
Cloud Composer:      $300
--------------------------------
TOTAL:              ~$940/month
```

### Example 3: Enterprise (10TB/day)

```
Daily Volume: 10TB (300TB/month)
Processing: Real-time streaming

Cloud Storage:        $400
BigQuery:            $800
Pub/Sub:             $400
Dataproc Serverless: $3,600
Cloud Functions:      $100
Cloud Composer:      $300
VPC, Security:       $200
--------------------------------
TOTAL:             ~$5,800/month

vs Traditional EMR/Redshift: ~$12,000/month
SAVINGS: ~$6,200/month (52%)
```

## Free Tier Benefits

GCP offers generous free tier (always free):

| Service | Free Tier |
|---------|-----------|
| Cloud Storage | 5GB/month |
| BigQuery | 1TB queries/month |
| BigQuery Storage | 10GB/month |
| Pub/Sub | 10GB/month |
| Cloud Functions | 2M invocations/month |
| Cloud Build | 120 build-minutes/day |

**Estimated Free Tier Value: ~$100/month**

## Cost Monitoring and Alerts

### Set Up Budget Alerts

```bash
# Create budget alert
gcloud billing budgets create \
    --billing-account=BILLING_ACCOUNT_ID \
    --display-name="Data Pipeline Budget" \
    --budget-amount=500 \
    --threshold-rule=percent=50 \
    --threshold-rule=percent=90 \
    --threshold-rule=percent=100
```

### Cost Attribution with Labels

All resources are tagged with:
- `environment`: dev/staging/prod
- `cost_center`: analytics
- `team`: data-engineering
- `managed_by`: terraform

View costs by label in Cloud Console:
```
https://console.cloud.google.com/billing/reports
```

### Export Billing to BigQuery

```bash
# Enable billing export
gcloud services enable billingbudgets.googleapis.com

# Analyze costs with SQL
SELECT
    service.description,
    SUM(cost) as total_cost
FROM `project.billing.gcp_billing_export_v1_BILLING_ID`
WHERE DATE(usage_start_time) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY service.description
ORDER BY total_cost DESC
```

## Cost Optimization Checklist

- [ ] Enable lifecycle policies on all buckets
- [ ] Partition and cluster BigQuery tables
- [ ] Use Dataproc Serverless instead of persistent clusters
- [ ] Set table expiration for temporary data
- [ ] Use committed use discounts for predictable workloads
- [ ] Enable autoscaling for Dataproc
- [ ] Use preemptible VMs for fault-tolerant workloads
- [ ] Implement data retention policies
- [ ] Monitor and delete unused resources
- [ ] Use Cloud CDN for frequently accessed data
- [ ] Compress data before storage
- [ ] Use appropriate storage classes (Standard/Nearline/Coldline/Archive)

## ROI Calculation

### Traditional Infrastructure

```
EMR Cluster:           $8,000/month
Kafka (MSK):           $1,500/month
RDS (PostgreSQL):      $500/month
EC2 (orchestration):   $300/month
S3:                    $200/month
--------------------------------
TOTAL:                ~$10,500/month
Annual:               ~$126,000
```

### This GCP Solution

```
Monthly cost:         ~$450/month
Annual:               ~$5,400
--------------------------------
ANNUAL SAVINGS:       ~$120,600 (95%)
```

### Break-even Analysis

Even with enterprise scale (10TB/day):
- GCP Solution: $5,800/month
- Traditional: $12,000/month
- **Payback period: Immediate**
- **3-year savings: ~$223,000**

## Conclusion

This GCP data pipeline provides:

✅ **95% cost savings** for small-medium workloads  
✅ **50%+ savings** for enterprise workloads  
✅ **Zero idle costs** with serverless architecture  
✅ **Automatic scaling** based on demand  
✅ **Pay-per-use** pricing model  
✅ **Built-in optimization** features  

**Recommendation:**
- **Start small** with the base configuration (~$100/month)
- **Scale gradually** as your data grows
- **Monitor costs** weekly using Cloud Billing
- **Optimize continuously** based on actual usage patterns
