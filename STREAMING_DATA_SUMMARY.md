# Sample Data & Streaming Testing - Summary

## 📊 Answer to Your Question

### Current Sample Data

**Before**: The pipeline used simple test messages:
```json
{"test": "data", "timestamp": "2024-12-02T10:30:45Z"}
```

**Now**: You have a **complete realistic data generator** that can produce:

1. ✅ **E-commerce Transactions** - Realistic shopping data
2. ✅ **User Activity Events** - User behavior tracking
3. ✅ **IoT Sensor Data** - Device telemetry
4. ✅ **Application Logs** - Service logging

## 🚀 Can Actual Streaming Data Be Used?

**YES!** You now have multiple options:

### Option 1: Generated Streaming Data (NEW!)
```bash
# Stream realistic data continuously
python scripts/generate_sample_data.py \
    --function-url YOUR_URL \
    --stream \
    --rate 10 \
    --type transaction
```

This simulates **real streaming data** at configurable rates!

### Option 2: Batch Data Generation
```bash
# Generate 1000 events at once
python scripts/generate_sample_data.py \
    --function-url YOUR_URL \
    --count 1000
```

### Option 3: Connect Real Data Sources

The pipeline is ready to receive data from:

**HTTP Sources** (via Cloud Function):
```python
import requests

# Any app can POST to your Cloud Function
requests.post(FUNCTION_URL, json={
    "data_type": "transaction",
    "payload": your_data
})
```

**Direct to Pub/Sub**:
```python
from google.cloud import pubsub_v1

publisher = pubsub_v1.PublisherClient()
topic = f"projects/{project_id}/topics/raw-data-topic-dev"
publisher.publish(topic, data)
```

**Streaming Sources**:
- Kafka (bridge to Pub/Sub)
- IoT devices
- Mobile/web apps
- Microservices
- Third-party APIs

## 📦 What You Got

### New Files Created:

1. **`scripts/generate_sample_data.py`** (462 lines)
   - Realistic data generator
   - Multiple data types
   - Batch and streaming modes
   - 1000 unique users, 600+ products

2. **`sample-data/sample_events.json`**
   - Example events for all data types
   - Ready to use for testing

3. **`sample-data/README.md`**
   - Complete usage guide
   - All command examples
   - Schema documentation

4. **`SAMPLE_DATA_GUIDE.md`**
   - Quick reference guide
   - Testing scenarios
   - Troubleshooting tips

5. **`scripts/requirements.txt`**
   - Python dependencies for generator

## 🎯 Quick Examples

### 1. Test with 10 Events
```bash
pip install -r scripts/requirements.txt

python scripts/generate_sample_data.py \
    --function-url $FUNCTION_URL \
    --count 10
```

### 2. Stream for 1 Minute
```bash
python scripts/generate_sample_data.py \
    --function-url $FUNCTION_URL \
    --stream \
    --rate 10 \
    --duration 60
```

### 3. High-Volume Test
```bash
python scripts/generate_sample_data.py \
    --mode pubsub \
    --project-id YOUR_PROJECT \
    --count 10000
```

### 4. Mixed Data Types
```bash
python scripts/generate_sample_data.py \
    --function-url $FUNCTION_URL \
    --stream \
    --rate 20 \
    --type mixed
```

## 📊 Data Characteristics

The generator creates **realistic distributions**:

- **Users**: 1000 unique IDs
- **Products**: 600+ across 6 categories
- **Regions**: 5 geographic areas
- **Prices**: Realistic ranges with ±10% variation
- **Mix**: 40% transactions, 30% activities, 20% IoT, 10% logs

## 🔄 Streaming Capabilities

### Supported Rates:
- **Low**: 1 event/sec (IoT simulation)
- **Normal**: 10-50 events/sec (typical operation)
- **High**: 100-500 events/sec (peak traffic)
- **Stress**: 1000+ events/sec (Black Friday!)

### Duration Options:
- **Fixed**: Specify duration (e.g., 60 seconds)
- **Continuous**: Run until stopped (Ctrl+C)
- **Scheduled**: Use with cron for regular testing

## 💡 Use Cases

### Development
```bash
# Quick test during development
python scripts/generate_sample_data.py --count 10
```

### Testing
```bash
# Automated testing in CI/CD
python scripts/generate_sample_data.py --count 100 --type mixed
```

### Load Testing
```bash
# Simulate peak traffic
python scripts/generate_sample_data.py \
    --stream --rate 100 --duration 300
```

### Continuous Monitoring
```bash
# Background stream for monitoring
nohup python scripts/generate_sample_data.py \
    --stream --rate 5 --type mixed &
```

## 🎯 Integration Points

The generated data flows through:

1. **Cloud Function** → Validates & enriches
2. **Pub/Sub** → Queues messages
3. **Cloud Storage** → Stores raw data
4. **Dataproc** → Processes with PySpark
5. **BigQuery** → Analytics queries

## 📚 Documentation

- **Full Guide**: `SAMPLE_DATA_GUIDE.md`
- **Data Schemas**: `sample-data/README.md`
- **Examples**: `sample-data/sample_events.json`
- **Generator Code**: `scripts/generate_sample_data.py`

## ✅ Summary

**Question**: Can actual streaming data be used?

**Answer**: YES! You now have:

1. ✅ **Realistic data generator** with multiple types
2. ✅ **Streaming mode** for continuous data flow
3. ✅ **Configurable rates** (1-1000+ events/sec)
4. ✅ **Production-ready schemas** matching your pipeline
5. ✅ **Multiple publishing modes** (HTTP/Pub/Sub)
6. ✅ **Load testing capabilities** for any scale

The pipeline is ready for **real streaming data** from any source! 🚀
