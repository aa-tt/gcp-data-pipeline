# Sample Data & Testing Guide

## 📊 Current Sample Data in Pipeline

The pipeline currently uses **simple test messages** in `scripts/test.sh`:

```json
{
  "test": "data",
  "timestamp": "2024-12-02T10:30:45Z"
}
```

And more structured data for Cloud Function testing:

```json
{
  "data_type": "test-transaction",
  "source_system": "test-system",
  "payload": {
    "user_id": "user-123",
    "product_id": "prod-456",
    "amount": 99.99,
    "quantity": 2,
    "category": "electronics",
    "region": "us-west"
  }
}
```

## 🚀 New: Realistic Streaming Data Generator

We've added a **comprehensive data generator** that can produce realistic streaming data!

### Features

✅ **4 Data Types**:
- E-commerce transactions
- User activity events
- IoT sensor data
- Application logs

✅ **2 Publishing Modes**:
- HTTP (via Cloud Function)
- Pub/Sub (direct)

✅ **2 Generation Modes**:
- Batch (fixed count)
- Stream (continuous)

✅ **Realistic Data**:
- 1000 unique users
- 600+ products
- Geographic regions
- Realistic distributions

## 📦 Quick Setup

```bash
# 1. Install dependencies
pip install -r scripts/requirements.txt

# 2. Get your Cloud Function URL
export FUNCTION_URL=$(gcloud functions describe data-ingestion-dev \
    --region=us-central1 --gen2 --format="value(serviceConfig.uri)")

# 3. Generate sample data!
```

## 🎯 Usage Examples

### 1. Basic Testing (10 Events)

```bash
python scripts/generate_sample_data.py \
    --function-url $FUNCTION_URL \
    --type transaction \
    --count 10
```

**Output:**
```
📊 Generating 10 transaction events...
  ✅ Published 10/10 messages
✅ Batch complete: 10/10 messages published
```

### 2. Medium Load (1000 Events)

```bash
python scripts/generate_sample_data.py \
    --function-url $FUNCTION_URL \
    --type transaction \
    --count 1000
```

### 3. Continuous Streaming (10 events/sec for 1 minute)

```bash
python scripts/generate_sample_data.py \
    --function-url $FUNCTION_URL \
    --stream \
    --rate 10 \
    --duration 60 \
    --type transaction
```

**Output:**
```
🔄 Starting continuous stream: 10.0 transaction/sec
   Duration: 60 seconds
  📈 100 messages sent (10.2/sec)
  📈 200 messages sent (10.1/sec)
  ...
✅ Stream complete: 600 messages in 59.8s (10.0/sec)
```

### 4. Mixed Data Types

```bash
python scripts/generate_sample_data.py \
    --function-url $FUNCTION_URL \
    --stream \
    --rate 20 \
    --duration 120 \
    --type mixed
```

**Distribution:**
- 40% Transactions
- 30% User Activities
- 20% IoT Sensors
- 10% Application Logs

### 5. Direct Pub/Sub (Faster for Bulk)

```bash
python scripts/generate_sample_data.py \
    --mode pubsub \
    --project-id YOUR_PROJECT_ID \
    --topic raw-data-topic-dev \
    --type transaction \
    --count 10000
```

### 6. IoT Sensor Simulation

```bash
# Simulate 50 sensors reporting every 30 seconds
python scripts/generate_sample_data.py \
    --function-url $FUNCTION_URL \
    --stream \
    --rate 1.67 \
    --type iot_sensor
```

### 7. High-Volume Load Test

```bash
# 100 events/second for 10 minutes = 60,000 events
python scripts/generate_sample_data.py \
    --mode pubsub \
    --project-id YOUR_PROJECT_ID \
    --stream \
    --rate 100 \
    --duration 600 \
    --type mixed
```

## 📋 Sample Data Schemas

### Transaction Event
```json
{
  "data_type": "transaction",
  "source_system": "data-generator",
  "payload": {
    "user_id": "user-a1b2c3d4",
    "product_id": "electronics-0042",
    "product_name": "Electronics Product 42",
    "amount": 147.85,
    "quantity": 2,
    "category": "electronics",
    "region": "us-west",
    "payment_method": "credit_card",
    "discount_applied": true,
    "timestamp": "2024-12-02T10:30:45.123456Z"
  }
}
```

### User Activity Event
```json
{
  "data_type": "user_activity",
  "source_system": "data-generator",
  "payload": {
    "user_id": "user-e5f6g7h8",
    "activity_type": "add_to_cart",
    "page_url": "/products/electronics",
    "session_id": "550e8400-e29b-41d4-a716-446655440000",
    "region": "eu-west",
    "device_type": "mobile",
    "timestamp": "2024-12-02T10:30:45.123456Z"
  }
}
```

### IoT Sensor Event
```json
{
  "data_type": "iot_sensor",
  "source_system": "data-generator",
  "payload": {
    "device_id": "sensor-0025",
    "temperature": 22.5,
    "humidity": 45.3,
    "pressure": 1013.2,
    "battery_level": 87.5,
    "location": "us-east",
    "status": "online",
    "timestamp": "2024-12-02T10:30:45.123456Z"
  }
}
```

### Application Log Event
```json
{
  "data_type": "application_log",
  "source_system": "data-generator",
  "payload": {
    "service": "payment-service",
    "log_level": "INFO",
    "message": "Request processed successfully",
    "request_id": "550e8400-e29b-41d4-a716-446655440000",
    "response_time_ms": 245,
    "status_code": 200,
    "timestamp": "2024-12-02T10:30:45.123456Z"
  }
}
```

## 🎮 Interactive Testing Workflow

### Complete End-to-End Test

```bash
# 1. Generate data
python scripts/generate_sample_data.py \
    --function-url $FUNCTION_URL \
    --count 100 \
    --type transaction

# 2. Wait for processing (give it 30 seconds)
sleep 30

# 3. Check data arrived in BigQuery
bq query --use_legacy_sql=false \
    'SELECT COUNT(*) as count FROM `YOUR_PROJECT.data_warehouse_dev.raw_data`'

# 4. Check Cloud Storage
gsutil ls gs://YOUR_PROJECT-processed-data-dev/processed/

# 5. Run PySpark ETL
gcloud dataproc batches submit pyspark \
    gs://YOUR_PROJECT-staging-dev/pyspark-jobs/etl_transform.py \
    --region=us-central1 \
    -- --project-id YOUR_PROJECT --environment dev

# 6. Query analytics data
bq query --use_legacy_sql=false \
    'SELECT category, COUNT(*) as count, SUM(amount) as revenue 
     FROM `YOUR_PROJECT.data_warehouse_dev.analytics_data` 
     GROUP BY category'
```

## 📊 Monitoring Your Test Data

### View Incoming Data
```bash
# Cloud Function logs
gcloud functions logs read data-ingestion-dev --limit=20

# Pub/Sub subscription
gcloud pubsub subscriptions pull raw-data-processing-sub-dev --limit=5

# BigQuery
bq query 'SELECT * FROM `PROJECT.data_warehouse_dev.raw_data` ORDER BY ingestion_timestamp DESC LIMIT 10'
```

### Check Processing Status
```bash
# Dataproc batch jobs
gcloud dataproc batches list --region=us-central1

# BigQuery analytics data
bq query 'SELECT DATE(event_date) as date, COUNT(*) as events 
          FROM `PROJECT.data_warehouse_dev.analytics_data` 
          GROUP BY date ORDER BY date DESC'
```

## 🎯 Recommended Test Scenarios

### Scenario 1: Smoke Test (5 minutes)
```bash
# Generate 50 events
python scripts/generate_sample_data.py --function-url $FUNCTION_URL --count 50
# Verify data in BigQuery
# Run ETL job
# Check results
```

### Scenario 2: Performance Test (30 minutes)
```bash
# Stream 1000 events over 10 minutes
python scripts/generate_sample_data.py \
    --function-url $FUNCTION_URL \
    --stream --rate 1.67 --duration 600
# Monitor Cloud Functions metrics
# Check BigQuery ingestion
```

### Scenario 3: Load Test (1 hour)
```bash
# Generate 100,000 events
python scripts/generate_sample_data.py \
    --mode pubsub \
    --project-id YOUR_PROJECT \
    --count 100000
# Monitor costs
# Check auto-scaling
# Validate data quality
```

### Scenario 4: Continuous Operation (24 hours)
```bash
# Run continuous stream at realistic rate
python scripts/generate_sample_data.py \
    --function-url $FUNCTION_URL \
    --stream --rate 5 --duration 86400 --type mixed
# Monitor for errors
# Check cost accumulation
# Validate end-to-end latency
```

## 💡 Tips

1. **Start Small**: Test with 10-100 events first
2. **Monitor Costs**: Use `gcloud billing` to track costs
3. **Use Pub/Sub Mode**: Faster for bulk loads (>1000 events)
4. **Check Logs**: Monitor for errors during streaming
5. **Verify Data**: Always query BigQuery to confirm
6. **Rate Limits**: Cloud Functions have quotas (default: 1000/sec)
7. **Cleanup**: Data lifecycle policies handle old data automatically

## 🚨 Troubleshooting

### Data Not Appearing in BigQuery
```bash
# Check Cloud Function logs
gcloud functions logs read data-ingestion-dev --limit=50 | grep ERROR

# Check Pub/Sub subscription
gcloud pubsub subscriptions describe raw-data-processing-sub-dev

# Check for dead letters
gcloud pubsub subscriptions pull dead-letter-monitor-sub-dev --limit=10
```

### High Latency
```bash
# Check Cloud Function performance
gcloud monitoring time-series list \
    --filter='metric.type="cloudfunctions.googleapis.com/function/execution_times"'

# Check Pub/Sub backlog
gcloud pubsub subscriptions describe raw-data-processing-sub-dev \
    --format="value(numUndeliveredMessages)"
```

### Cost Concerns
```bash
# Check current month costs
gcloud billing accounts list

# Set budget alert (recommended)
gcloud billing budgets create \
    --billing-account ACCOUNT_ID \
    --display-name "Data Pipeline Test Budget" \
    --budget-amount 100
```

## 🎉 Success Metrics

After running tests, you should see:

✅ Messages published successfully  
✅ Cloud Function invocations (check logs)  
✅ Data in BigQuery raw_data table  
✅ Processed data in Cloud Storage  
✅ PySpark job completes successfully  
✅ Analytics data in BigQuery  
✅ No errors in Cloud Logging  

Enjoy realistic data testing! 🚀
