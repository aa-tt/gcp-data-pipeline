# Schema Fixes

## Overview
This document describes the schema mismatches encountered during deployment and how they were resolved.

## Issues Encountered

### 1. Event Timestamp Type Mismatch

**Error:**
```
Field event_timestamp has changed type from TIMESTAMP to STRING
```

**Root Cause:**
- The `ingestion_timestamp` field from GCS JSON files was being read as STRING by PySpark
- Directly assigning it to `event_timestamp` without type conversion caused a mismatch with BigQuery's TIMESTAMP schema

**Solution:**
Updated `pyspark-jobs/etl_transform.py` line ~107:
```python
# Before (WRONG):
df = df.withColumn("event_timestamp", F.col("ingestion_timestamp"))

# After (CORRECT):
df = df.withColumn("event_timestamp", F.to_timestamp(F.col("ingestion_timestamp")))
```

**Files Changed:**
- `pyspark-jobs/etl_transform.py`

---

### 2. Attributes Field Type Mismatch

**Error:**
```
Field attributes has changed type from JSON to STRING
```

**Root Cause:**
- PySpark's `F.to_json()` function creates a STRING representation of JSON, not a JSON type
- BigQuery table was initially configured with JSON type, but Spark writes it as STRING

**Solution:**
Updated BigQuery table schema in `terraform/modules/bigquery/main.tf`:
```hcl
# Changed from:
{
  name        = "attributes"
  type        = "JSON"      # Wrong
  mode        = "NULLABLE"
}

# To:
{
  name        = "attributes"
  type        = "STRING"     # Correct
  mode        = "NULLABLE"
  description = "Additional attributes as JSON string"
}
```

**Files Changed:**
- `terraform/modules/bigquery/main.tf`
- BigQuery table recreated manually with: `bq mk --table ...`

---

### 3. Missing Transaction ID Field

**Error:**
```
Schema mismatch - missing field transaction_id
```

**Root Cause:**
- The PySpark transformation extracts `transaction_id` from the data
- This field was missing from the original BigQuery table schema

**Solution:**
Added `transaction_id` field to the schema in `terraform/modules/bigquery/main.tf`:
```hcl
{
  name        = "transaction_id"
  type        = "STRING"
  mode        = "NULLABLE"
  description = "Transaction identifier"
}
```

**Files Changed:**
- `terraform/modules/bigquery/main.tf`

---

### 4. Metrics Value Type Mismatch

**Error:**
```
Field value has changed type from NUMERIC to FLOAT
```

**Root Cause:**
- PySpark aggregations (sum, avg) return FLOAT/DOUBLE types
- BigQuery table was configured with NUMERIC type

**Solution:**
Updated `terraform/modules/bigquery/main.tf` for daily_metrics table:
```hcl
# Changed from:
{
  name        = "value"
  type        = "NUMERIC"    # Wrong
  mode        = "REQUIRED"
}

# To:
{
  name        = "value"
  type        = "FLOAT"       # Correct
  mode        = "NULLABLE"
}
```

**Files Changed:**
- `terraform/modules/bigquery/main.tf`

---

## Terraform State Management

After manually creating/updating BigQuery tables, they needed to be imported into Terraform state:

```bash
# Import BigQuery dataset
terraform import module.bigquery.google_bigquery_dataset.data_warehouse datapipeline-480007/data_warehouse_dev

# Import analytics_data table
terraform import module.bigquery.google_bigquery_table.analytics datapipeline-480007/data_warehouse_dev/analytics_data

# Import daily_metrics table
terraform import module.bigquery.google_bigquery_table.metrics datapipeline-480007/data_warehouse_dev/daily_metrics
```

---

## Best Practices Learned

### 1. **Type Consistency**
- Always explicitly convert data types in PySpark before writing to BigQuery
- Use `F.to_timestamp()` for timestamps
- Use `F.cast()` for explicit type conversions

### 2. **Schema Design**
- Match BigQuery schema types to Spark's output types:
  - Spark FLOAT/DOUBLE → BigQuery FLOAT (not NUMERIC)
  - Spark STRING → BigQuery STRING (for JSON strings, not JSON type)
  - Spark TimestampType → BigQuery TIMESTAMP

### 3. **Terraform Workflow**
- Define infrastructure as code BEFORE manual changes
- If manual changes are required, immediately import them into Terraform state
- Run `terraform plan` regularly to catch drift

### 4. **Testing Strategy**
- Test PySpark jobs with sample data before production deployment
- Verify schema compatibility with small data loads first
- Use `NULLABLE` mode for fields that might be missing in source data

---

## Schema Definitions

### Final analytics_data Schema
```json
[
  {"name": "event_date", "type": "DATE", "mode": "NULLABLE"},
  {"name": "event_timestamp", "type": "TIMESTAMP", "mode": "NULLABLE"},
  {"name": "user_id", "type": "STRING", "mode": "NULLABLE"},
  {"name": "product_id", "type": "STRING", "mode": "NULLABLE"},
  {"name": "transaction_id", "type": "STRING", "mode": "NULLABLE"},
  {"name": "category", "type": "STRING", "mode": "NULLABLE"},
  {"name": "region", "type": "STRING", "mode": "NULLABLE"},
  {"name": "amount", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "quantity", "type": "INTEGER", "mode": "NULLABLE"},
  {"name": "attributes", "type": "STRING", "mode": "NULLABLE"}
]
```

### Final daily_metrics Schema
```json
[
  {"name": "metric_date", "type": "DATE", "mode": "NULLABLE"},
  {"name": "metric_name", "type": "STRING", "mode": "REQUIRED"},
  {"name": "dimension", "type": "STRING", "mode": "NULLABLE"},
  {"name": "value", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "count", "type": "INTEGER", "mode": "REQUIRED"}
]
```

---

## References

- [PySpark SQL Functions](https://spark.apache.org/docs/latest/api/python/reference/pyspark.sql/functions.html)
- [BigQuery Data Types](https://cloud.google.com/bigquery/docs/reference/standard-sql/data-types)
- [Spark BigQuery Connector](https://github.com/GoogleCloudDataproc/spark-bigquery-connector)
- [Terraform Import](https://developer.hashicorp.com/terraform/cli/import)

---

## Change Log

| Date | Change | Author | Files |
|------|--------|--------|-------|
| 2025-12-03 | Fixed timestamp conversion | System | etl_transform.py |
| 2025-12-03 | Updated schema types (FLOAT, STRING) | System | main.tf |
| 2025-12-03 | Added transaction_id field | System | main.tf |
| 2025-12-04 | Imported tables to Terraform state | System | terraform state |
| 2025-12-04 | Added dataproc.editor permission | System | main.tf |
