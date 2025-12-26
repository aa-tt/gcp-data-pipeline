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
import functions_framework

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Environment variables
PROJECT_ID = os.environ.get('GCP_PROJECT')
PUBSUB_TOPIC = os.environ.get('PUBSUB_TOPIC')
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')

# Initialize Pub/Sub publisher
publisher = pubsub_v1.PublisherClient()


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
        
        return (
            {
                'status': 'success',
                'message_id': message_id,
                'record_id': enriched_data['id']
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
    return {'status': 'healthy', 'timestamp': datetime.utcnow().isoformat()}, 200
