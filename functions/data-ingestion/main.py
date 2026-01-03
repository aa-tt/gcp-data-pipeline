"""
Cloud Function for Data Ingestion
HTTP-triggered function that receives data and publishes to Pub/Sub

This function demonstrates:
1. Receiving HTTP POST requests with JSON data
2. Validating and enriching the data
3. Publishing to Pub/Sub for downstream processing
"""

import json
import os
import logging
from datetime import datetime
from google.cloud import pubsub_v1
from google.cloud import spanner
import functions_framework

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Environment variables
PROJECT_ID = os.environ.get('GCP_PROJECT')
PUBSUB_TOPIC = os.environ.get('PUBSUB_TOPIC')
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')
SPANNER_INSTANCE = os.environ.get('SPANNER_INSTANCE')  # Optional
SPANNER_DATABASE = os.environ.get('SPANNER_DATABASE', 'transactions-db')

# Initialize Pub/Sub publisher
publisher = pubsub_v1.PublisherClient()

# Initialize Spanner client (only if instance is configured)
spanner_client = None
spanner_db = None
if SPANNER_INSTANCE:
    try:
        spanner_client = spanner.Client(project=PROJECT_ID)
        instance = spanner_client.instance(SPANNER_INSTANCE)
        spanner_db = instance.database(SPANNER_DATABASE)
        logger.info(f"Spanner enabled: {SPANNER_INSTANCE}/{SPANNER_DATABASE}")
    except Exception as e:
        logger.warning(f"Spanner initialization failed: {e}. Continuing without Spanner.")


@functions_framework.http
def ingest_data(request):
    """
    HTTP Cloud Function to ingest data
    
    Args:
        request (flask.Request): HTTP request object
        
    Returns:
        Tuple of (response_text, status_code)
    """
    # Set CORS headers for all responses
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Max-Age': '3600'
    }
    
    # Handle preflight OPTIONS request
    if request.method == 'OPTIONS':
        return ('', 204, headers)
    
    try:
        # Parse request
        request_json = request.get_json(silent=True)
        
        if not request_json:
            return ({'error': 'No JSON data provided'}, 400, headers)
        
        # Validate required fields
        required_fields = ['data_type', 'payload']
        missing_fields = [field for field in required_fields if field not in request_json]
        
        if missing_fields:
            return (
                {'error': f'Missing required fields: {", ".join(missing_fields)}'},
                400,
                headers
            )
        
        # Extract transaction details
        payload = request_json['payload']
        transaction_id = payload.get('transaction_id')
        
        # Check for duplicate transaction in Spanner (if enabled)
        if spanner_db and transaction_id:
            duplicate_check = check_duplicate_transaction(transaction_id)
            if duplicate_check:
                logger.warning(f"Duplicate transaction detected: {transaction_id}")
                return (
                    {
                        'status': 'duplicate',
                        'message': 'Transaction already processed',
                        'transaction_id': transaction_id,
                        'original_status': duplicate_check['status'],
                        'created_at': duplicate_check['created_at']
                    },
                    409,  # Conflict
                    headers
                )
        
        # Enrich data with metadata
        enriched_data = {
            'id': f"{request_json.get('data_type')}-{datetime.utcnow().timestamp()}",
            'ingestion_timestamp': datetime.utcnow().isoformat(),
            'source_system': request_json.get('source_system', 'api'),
            'data_type': request_json['data_type'],
            'raw_payload': json.dumps(request_json['payload']),
            'metadata': {
                'version': request_json.get('version', '1.0'),
                'environment': ENVIRONMENT,
                'ingestion_method': 'cloud-function-http'
            }
        }
        
        # Publish to Pub/Sub
        message_data = json.dumps(enriched_data).encode('utf-8')
        future = publisher.publish(PUBSUB_TOPIC, message_data)
        message_id = future.result()
        
        logger.info(f"Published message {message_id} to {PUBSUB_TOPIC}")
        
        # Write transaction to Spanner for deduplication (if enabled)
        if spanner_db and transaction_id:
            write_transaction_to_spanner(enriched_data, payload)
        
        return (
            {
                'status': 'success',
                'message_id': message_id,
                'record_id': enriched_data['id'],
                'transaction_id': transaction_id
            },
            200,
            headers
        )
        
    except Exception as e:
        logger.error(f"Error ingesting data: {str(e)}", exc_info=True)
        return ({'error': str(e)}, 500, headers)


@functions_framework.http
def health_check(request):
    """Health check endpoint"""
    spanner_status = "enabled" if spanner_db else "disabled"
    return {
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'spanner': spanner_status
    }, 200


def check_duplicate_transaction(transaction_id):
    """Check if transaction already exists in Spanner"""
    try:
        with spanner_db.snapshot() as snapshot:
            results = snapshot.execute_sql(
                """
                SELECT transaction_id, status, created_at
                FROM transactions
                WHERE transaction_id = @txn_id
                """,
                params={'txn_id': transaction_id},
                param_types={'txn_id': spanner.param_types.STRING}
            )
            
            rows = list(results)
            if rows:
                row = rows[0]
                return {
                    'transaction_id': row[0],
                    'status': row[1],
                    'created_at': row[2].isoformat() if row[2] else None
                }
            return None
    except Exception as e:
        logger.error(f"Error checking Spanner for duplicate: {e}")
        return None  # Don't block on Spanner errors


def write_transaction_to_spanner(enriched_data, payload):
    """Write transaction record to Spanner"""
    try:
        with spanner_db.batch() as batch:
            batch.insert(
                table='transactions',
                columns=[
                    'transaction_id', 'user_id', 'product_id', 'amount',
                    'quantity', 'status', 'event_name', 'created_at',
                    'updated_at', 'metadata', 'source_system'
                ],
                values=[[
                    payload.get('transaction_id'),
                    payload.get('user_id'),
                    payload.get('product_id'),
                    float(payload.get('amount', 0)),
                    int(payload.get('quantity', 1)),
                    'pending',
                    payload.get('event_name', 'transaction'),
                    spanner.COMMIT_TIMESTAMP,
                    spanner.COMMIT_TIMESTAMP,
                    enriched_data.get('metadata'),
                    enriched_data.get('source_system')
                ]]
            )
        logger.info(f"Transaction written to Spanner: {payload.get('transaction_id')}")
    except Exception as e:
        logger.error(f"Error writing to Spanner: {e}")
        # Don't fail the request if Spanner write fails

