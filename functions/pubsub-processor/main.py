"""
Cloud Function for Pub/Sub Message Processing
Event-triggered function that processes Pub/Sub messages

This function demonstrates:
1. Processing Pub/Sub messages
2. Transforming/validating data
3. Writing to Cloud Storage
4. Optionally writing to BigQuery
"""

import base64
import json
import os
import logging
from datetime import datetime
from google.cloud import storage
from google.cloud import bigquery
import functions_framework

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Environment variables
PROJECT_ID = os.environ.get('GCP_PROJECT')
PROCESSED_BUCKET = os.environ.get('PROCESSED_BUCKET')
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')

# Initialize clients
storage_client = storage.Client()
bq_client = bigquery.Client()


@functions_framework.cloud_event
def process_message(cloud_event):
    """
    Background Cloud Function triggered by Pub/Sub
    
    Args:
        cloud_event: CloudEvent object containing Pub/Sub message
    """
    try:
        # Decode Pub/Sub message
        pubsub_message = base64.b64decode(cloud_event.data["message"]["data"]).decode('utf-8')
        message_data = json.loads(pubsub_message)
        
        logger.info(f"Processing message: {message_data.get('id')}")
        
        # Validate message
        if not validate_message(message_data):
            logger.warning(f"Invalid message: {message_data.get('id')}")
            return
        
        # Transform/enrich data
        processed_data = transform_data(message_data)
        
        # Write to Cloud Storage
        write_to_gcs(processed_data)
        
        logger.info(f"Successfully processed message: {message_data.get('id')}")
        
    except Exception as e:
        logger.error(f"Error processing message: {str(e)}", exc_info=True)
        # Re-raise to trigger retry
        raise


def validate_message(message):
    """Validate message has required fields"""
    required_fields = ['id', 'data_type', 'raw_payload']
    return all(field in message for field in required_fields)


def transform_data(message):
    """Transform and enrich the message data"""
    try:
        # Parse raw payload if it's a string
        if isinstance(message.get('raw_payload'), str):
            payload = json.loads(message['raw_payload'])
        else:
            payload = message.get('raw_payload', {})
        
        # Create processed record
        processed = {
            'id': message['id'],
            'processed_timestamp': datetime.utcnow().isoformat(),
            'ingestion_timestamp': message.get('ingestion_timestamp'),
            'source_system': message.get('source_system'),
            'data_type': message.get('data_type'),
            'data': payload,
            'metadata': {
                **message.get('metadata', {}),
                'processed_by': 'cloud-function',
                'processing_environment': ENVIRONMENT
            }
        }
        
        return processed
        
    except Exception as e:
        logger.error(f"Error transforming data: {str(e)}")
        raise


def write_to_gcs(data):
    """Write processed data to Cloud Storage"""
    try:
        bucket = storage_client.bucket(PROCESSED_BUCKET)
        
        # Create path with partitioning by date and type
        date_str = datetime.utcnow().strftime('%Y/%m/%d')
        data_type = data.get('data_type', 'unknown')
        record_id = data.get('id')
        
        blob_name = f"processed/{data_type}/{date_str}/{record_id}.json"
        blob = bucket.blob(blob_name)
        
        # Upload as JSON
        blob.upload_from_string(
            json.dumps(data, indent=2),
            content_type='application/json'
        )
        
        logger.info(f"Written to GCS: gs://{PROCESSED_BUCKET}/{blob_name}")
        
    except Exception as e:
        logger.error(f"Error writing to GCS: {str(e)}")
        raise


def write_to_bigquery(data):
    """Write processed data to BigQuery"""
    try:
        dataset_id = f"data_warehouse_{ENVIRONMENT}"
        table_id = "raw_data"
        table_ref = f"{PROJECT_ID}.{dataset_id}.{table_id}"
        
        # Prepare row for BigQuery
        row = {
            'id': data['id'],
            'ingestion_timestamp': data.get('ingestion_timestamp'),
            'source_system': data.get('source_system'),
            'data_type': data.get('data_type'),
            'raw_payload': json.dumps(data.get('data')),
            'metadata': data.get('metadata', {})
        }
        
        errors = bq_client.insert_rows_json(table_ref, [row])
        
        if errors:
            logger.error(f"Errors writing to BigQuery: {errors}")
        else:
            logger.info(f"Written to BigQuery: {table_ref}")
            
    except Exception as e:
        logger.error(f"Error writing to BigQuery: {str(e)}")
        # Don't re-raise - GCS write is primary, BQ is secondary
