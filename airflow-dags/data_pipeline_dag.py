"""
Airflow DAG for Data Pipeline Orchestration

This DAG orchestrates the complete data pipeline:
1. Check for new data in Pub/Sub
2. Trigger PySpark ETL job on Dataproc Serverless
3. Validate data quality
4. Generate metrics and reports
5. Send notifications

Schedule: Daily at 2 AM
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.google.cloud.operators.dataproc import DataprocSubmitJobOperator
from airflow.providers.google.cloud.operators.bigquery import (
    BigQueryCheckOperator,
    BigQueryInsertJobOperator,
)
from airflow.providers.google.cloud.operators.gcs import GCSFileTransformOperator
from airflow.providers.google.cloud.sensors.gcs import GCSObjectExistenceSensor
from airflow.operators.python import PythonOperator
from airflow.operators.email import EmailOperator
from airflow.utils.task_group import TaskGroup
import os

# Environment variables
PROJECT_ID = os.environ.get('GCP_PROJECT')
REGION = 'us-central1'
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')

# GCS buckets
STAGING_BUCKET = f"{PROJECT_ID}-staging-{ENVIRONMENT}"
PROCESSED_BUCKET = f"{PROJECT_ID}-processed-data-{ENVIRONMENT}"

# BigQuery
DATASET_ID = f"data_warehouse_{ENVIRONMENT}"

# Default arguments
default_args = {
    'owner': 'data-team',
    'depends_on_past': False,
    'email': ['data-team@example.com'],
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 3,
    'retry_delay': timedelta(minutes=5),
    'retry_exponential_backoff': True,
    'max_retry_delay': timedelta(minutes=30),
}

# Create DAG
dag = DAG(
    'data_pipeline_etl',
    default_args=default_args,
    description='Daily data ETL pipeline',
    schedule_interval='0 2 * * *',  # 2 AM daily
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['data-pipeline', 'etl', 'production'],
)


def check_data_availability(**context):
    """Check if there's data to process"""
    from google.cloud import bigquery
    
    client = bigquery.Client()
    execution_date = context['ds']
    
    query = f"""
        SELECT COUNT(*) as record_count
        FROM `{PROJECT_ID}.{DATASET_ID}.raw_data`
        WHERE DATE(ingestion_timestamp) = '{execution_date}'
    """
    
    result = client.query(query).result()
    count = list(result)[0].record_count
    
    print(f"Found {count} records for {execution_date}")
    
    if count == 0:
        raise ValueError(f"No data found for {execution_date}")
    
    return count


def validate_data_quality(**context):
    """Validate processed data quality"""
    from google.cloud import bigquery
    
    client = bigquery.Client()
    execution_date = context['ds']
    
    # Check for null values in critical fields
    query = f"""
        SELECT 
            COUNTIF(user_id IS NULL) as null_users,
            COUNTIF(amount IS NULL) as null_amounts,
            COUNTIF(amount < 0) as negative_amounts,
            COUNT(*) as total_records
        FROM `{PROJECT_ID}.{DATASET_ID}.analytics_data`
        WHERE event_date = '{execution_date}'
    """
    
    result = client.query(query).result()
    stats = list(result)[0]
    
    # Validate quality thresholds
    if stats.null_users > stats.total_records * 0.1:  # Max 10% null users
        raise ValueError(f"Too many null user_ids: {stats.null_users}/{stats.total_records}")
    
    if stats.negative_amounts > 0:
        raise ValueError(f"Found negative amounts: {stats.negative_amounts}")
    
    print(f"Data quality check passed for {execution_date}")
    return True


def generate_summary_report(**context):
    """Generate summary report"""
    from google.cloud import bigquery
    
    client = bigquery.Client()
    execution_date = context['ds']
    
    query = f"""
        SELECT 
            category,
            region,
            COUNT(*) as transactions,
            SUM(amount) as total_amount,
            AVG(amount) as avg_amount
        FROM `{PROJECT_ID}.{DATASET_ID}.analytics_data`
        WHERE event_date = '{execution_date}'
        GROUP BY category, region
        ORDER BY total_amount DESC
        LIMIT 10
    """
    
    result = client.query(query).result()
    
    print(f"\n=== Summary Report for {execution_date} ===")
    for row in result:
        print(f"{row.category} - {row.region}: {row.transactions} txns, ${row.total_amount:,.2f}")
    
    return True


# Task 1: Check data availability
check_data = PythonOperator(
    task_id='check_data_availability',
    python_callable=check_data_availability,
    provide_context=True,
    dag=dag,
)

# Task 2: Submit PySpark ETL job to Dataproc Serverless
pyspark_job = {
    "reference": {"project_id": PROJECT_ID},
    "placement": {"cluster_name": ""},
    "pyspark_job": {
        "main_python_file_uri": f"gs://{STAGING_BUCKET}/pyspark-jobs/etl_transform.py",
        "args": [
            "--project-id", PROJECT_ID,
            "--environment", ENVIRONMENT,
            "--date", "{{ ds }}"
        ],
        "jar_file_uris": [],
        "properties": {
            "spark.executor.memory": "4g",
            "spark.executor.cores": "2",
            "spark.dynamicAllocation.enabled": "true",
        }
    },
}

# For Dataproc Serverless (Batch API)
submit_etl_job = DataprocSubmitJobOperator(
    task_id='submit_pyspark_etl',
    job=pyspark_job,
    region=REGION,
    project_id=PROJECT_ID,
    dag=dag,
)

# Task 3: Validate data quality
validate_quality = PythonOperator(
    task_id='validate_data_quality',
    python_callable=validate_data_quality,
    provide_context=True,
    dag=dag,
)

# Task 4: Data quality checks using BigQuery
with TaskGroup('bigquery_checks', dag=dag) as bq_checks:
    
    # Check for duplicates
    check_duplicates = BigQueryCheckOperator(
        task_id='check_duplicates',
        sql=f"""
            SELECT COUNT(*) = COUNT(DISTINCT id)
            FROM `{PROJECT_ID}.{DATASET_ID}.analytics_data`
            WHERE event_date = '{{{{ ds }}}}'
        """,
        use_legacy_sql=False,
    )
    
    # Check record count
    check_record_count = BigQueryCheckOperator(
        task_id='check_record_count',
        sql=f"""
            SELECT COUNT(*) > 0
            FROM `{PROJECT_ID}.{DATASET_ID}.analytics_data`
            WHERE event_date = '{{{{ ds }}}}'
        """,
        use_legacy_sql=False,
    )
    
    check_duplicates >> check_record_count

# Task 5: Update aggregated metrics
update_metrics = BigQueryInsertJobOperator(
    task_id='update_aggregated_metrics',
    configuration={
        "query": {
            "query": f"""
                INSERT INTO `{PROJECT_ID}.{DATASET_ID}.daily_metrics`
                SELECT 
                    DATE('{{{{ ds }}}}') as metric_date,
                    'daily_total' as metric_name,
                    category as dimension,
                    SUM(amount) as value,
                    COUNT(*) as count
                FROM `{PROJECT_ID}.{DATASET_ID}.analytics_data`
                WHERE event_date = '{{{{ ds }}}}'
                GROUP BY category
            """,
            "useLegacySql": False,
        }
    },
    dag=dag,
)

# Task 6: Generate summary report
generate_report = PythonOperator(
    task_id='generate_summary_report',
    python_callable=generate_summary_report,
    provide_context=True,
    dag=dag,
)

# Task 7: Send success notification
send_notification = EmailOperator(
    task_id='send_success_notification',
    to='data-team@example.com',
    subject='Data Pipeline Success - {{ ds }}',
    html_content="""
        <h3>Data Pipeline Completed Successfully</h3>
        <p>Date: {{ ds }}</p>
        <p>Execution time: {{ execution_date }}</p>
        <p>All tasks completed successfully.</p>
    """,
    dag=dag,
)

# Define task dependencies
check_data >> submit_etl_job >> validate_quality >> bq_checks
bq_checks >> update_metrics >> generate_report >> send_notification
