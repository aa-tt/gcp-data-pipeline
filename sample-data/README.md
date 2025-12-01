# Sample Data for GCP Data Pipeline

This directory contains sample data for testing the pipeline.

## Data Types

### 1. E-commerce Transactions
Realistic e-commerce transaction data with:
- User and product information
- Pricing and quantity
- Payment methods
- Regional data

### 2. User Activity Events
User interaction tracking:
- Page views
- Cart actions
- Search queries
- Session data

### 3. IoT Sensor Data
Simulated IoT device readings:
- Temperature, humidity, pressure
- Battery levels
- Device status
- Location data

### 4. Application Logs
Service log entries:
- Log levels
- Response times
- Status codes
- Request tracking

## Sample Files

- `sample_events.json` - Example events for all data types
- `bulk_transactions.json` - Large dataset for load testing (generated on demand)

## Using the Data Generator

### Quick Start

```bash
# Install dependencies
pip install -r scripts/requirements.txt

# Generate 100 sample transactions via HTTP
python scripts/generate_sample_data.py \
    --mode http \
    --function-url "YOUR_CLOUD_FUNCTION_URL" \
    --type transaction \
    --count 100

# Stream data continuously at 10 events/second
python scripts/generate_sample_data.py \
    --mode http \
    --function-url "YOUR_CLOUD_FUNCTION_URL" \
    --type transaction \
    --stream \
    --rate 10 \
    --duration 60
```

### Publishing to Pub/Sub Directly

```bash
# Batch mode
python scripts/generate_sample_data.py \
    --mode pubsub \
    --project-id YOUR_PROJECT_ID \
    --topic raw-data-topic-dev \
    --type transaction \
    --count 1000

# Streaming mode
python scripts/generate_sample_data.py \
    --mode pubsub \
    --project-id YOUR_PROJECT_ID \
    --topic raw-data-topic-dev \
    --type mixed \
    --stream \
    --rate 50 \
    --duration 300
```

## Data Generator Options

### Modes
- `--mode http` - Send via Cloud Function (default)
- `--mode pubsub` - Send directly to Pub/Sub

### Data Types
- `transaction` - E-commerce transactions (default)
- `user_activity` - User activity events
- `iot_sensor` - IoT sensor readings
- `application_log` - Application logs
- `mixed` - Mix of all types

### Generation Modes
- **Batch** (default): Generate fixed number of events
  - `--count N` - Number of events (default: 100)
  
- **Stream** (`--stream`): Generate continuous stream
  - `--rate N` - Events per second (default: 10)
  - `--duration N` - Duration in seconds (optional)

## Example Usage Scenarios

### 1. Test Basic Functionality
```bash
# Generate 10 test transactions
python scripts/generate_sample_data.py \
    --function-url $FUNCTION_URL \
    --count 10
```

### 2. Load Testing
```bash
# Generate 10,000 events as fast as possible
python scripts/generate_sample_data.py \
    --mode pubsub \
    --project-id $PROJECT_ID \
    --count 10000
```

### 3. Continuous Streaming Simulation
```bash
# Simulate realistic traffic: 100 events/second for 1 hour
python scripts/generate_sample_data.py \
    --function-url $FUNCTION_URL \
    --stream \
    --rate 100 \
    --duration 3600 \
    --type mixed
```

### 4. IoT Device Simulation
```bash
# Simulate 20 IoT sensors reporting every 5 seconds
python scripts/generate_sample_data.py \
    --function-url $FUNCTION_URL \
    --stream \
    --rate 0.2 \
    --type iot_sensor
```

### 5. Stress Testing
```bash
# High volume: 1000 events/second for 5 minutes
python scripts/generate_sample_data.py \
    --mode pubsub \
    --project-id $PROJECT_ID \
    --stream \
    --rate 1000 \
    --duration 300 \
    --type mixed
```

## Sample Data Schema

### Transaction Event
```json
{
  "data_type": "transaction",
  "source_system": "pos-system",
  "payload": {
    "user_id": "user-abc123",
    "product_id": "electronics-0042",
    "product_name": "Wireless Headphones",
    "amount": 89.99,
    "quantity": 1,
    "category": "electronics",
    "region": "us-west",
    "payment_method": "credit_card",
    "discount_applied": true,
    "timestamp": "2024-12-02T10:30:45.123Z"
  }
}
```

### User Activity Event
```json
{
  "data_type": "user_activity",
  "source_system": "web-analytics",
  "payload": {
    "user_id": "user-xyz789",
    "activity_type": "add_to_cart",
    "page_url": "/products/electronics",
    "session_id": "sess-abc123",
    "region": "us-west",
    "device_type": "mobile",
    "timestamp": "2024-12-02T10:30:45.123Z"
  }
}
```

### IoT Sensor Event
```json
{
  "data_type": "iot_sensor",
  "source_system": "warehouse-iot",
  "payload": {
    "device_id": "sensor-0025",
    "temperature": 22.5,
    "humidity": 45.3,
    "pressure": 1013.2,
    "battery_level": 87.5,
    "location": "us-east",
    "status": "online",
    "timestamp": "2024-12-02T10:30:45.123Z"
  }
}
```

### Application Log Event
```json
{
  "data_type": "application_log",
  "source_system": "payment-service",
  "payload": {
    "service": "payment-service",
    "log_level": "INFO",
    "message": "Payment processed successfully",
    "request_id": "req-abc123",
    "response_time_ms": 245,
    "status_code": 200,
    "timestamp": "2024-12-02T10:30:45.123Z"
  }
}
```

## Manual Testing with curl

### Send Single Event
```bash
FUNCTION_URL="your-cloud-function-url"

curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "data_type": "transaction",
    "source_system": "test",
    "payload": {
      "user_id": "user-test-001",
      "product_id": "prod-test-001",
      "amount": 99.99,
      "quantity": 1,
      "category": "electronics",
      "region": "us-west"
    }
  }'
```

### Send Multiple Events
```bash
# Loop to send multiple events
for i in {1..10}; do
  curl -X POST "$FUNCTION_URL" \
    -H "Content-Type: application/json" \
    -d '{
      "data_type": "transaction",
      "payload": {
        "user_id": "user-'$i'",
        "amount": '$((RANDOM % 100 + 10))',
        "category": "test"
      }
    }'
  sleep 1
done
```

## Manual Testing with gcloud

### Publish to Pub/Sub
```bash
# Single message
gcloud pubsub topics publish raw-data-topic-dev \
  --message='{"user_id": "test-user", "amount": 50.00}'

# Multiple messages
for i in {1..100}; do
  gcloud pubsub topics publish raw-data-topic-dev \
    --message='{"id": "'$i'", "amount": '$((RANDOM % 100))'}'
done
```

## Data Characteristics

### Realistic Distributions

The generator creates realistic data with:

1. **Users**: 1000 unique user IDs
2. **Products**: 600+ products across 6 categories
3. **Regions**: 5 geographic regions
4. **Price Variation**: ±10% from base price
5. **Activity Mix**: 
   - 40% Transactions
   - 30% User Activities
   - 20% IoT Sensors
   - 10% Application Logs

### Load Testing Profiles

| Profile | Rate | Duration | Total Events | Use Case |
|---------|------|----------|--------------|----------|
| Light | 1/sec | 60s | 60 | Smoke test |
| Normal | 10/sec | 300s | 3,000 | Regular operation |
| Heavy | 100/sec | 600s | 60,000 | Peak hours |
| Stress | 1000/sec | 300s | 300,000 | Black Friday |

## Tips

1. **Start Small**: Begin with 10-100 events to test
2. **Monitor Costs**: High-volume testing can incur charges
3. **Use Pub/Sub Mode**: Faster for bulk operations
4. **Check Logs**: Monitor Cloud Functions logs for errors
5. **Verify Data**: Query BigQuery to confirm data arrival

## Cleanup

After testing, data will be automatically cleaned up based on lifecycle policies:
- Raw data: 30 days → Coldline → 90 days delete
- Processed data: 60 days → Nearline
- BigQuery: Partitioned tables with optional expiration
