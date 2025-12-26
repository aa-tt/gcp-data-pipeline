"""
Cloud Function to query BigQuery analytics data and metrics
"""
import os
import json
import functions_framework
from google.cloud import bigquery
from datetime import datetime, timedelta
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize BigQuery client
project_id = os.environ.get('GCP_PROJECT')
environment = os.environ.get('ENVIRONMENT', 'dev')
client = bigquery.Client(project=project_id)


@functions_framework.http
def query_analytics(request):
    """
    HTTP Cloud Function to query analytics data and daily metrics
    
    Query parameters:
    - days: Number of days to look back (default: 7)
    - limit: Maximum number of records to return (default: 100)
    """
    # Set CORS headers for preflight requests
    if request.method == 'OPTIONS':
        headers = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Max-Age': '3600'
        }
        return ('', 204, headers)

    # Set CORS headers for main request
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'application/json'
    }

    try:
        # Get query parameters
        days = int(request.args.get('days', 7))
        limit = int(request.args.get('limit', 100))
        
        # Calculate date range
        end_date = datetime.now().date()
        start_date = end_date - timedelta(days=days)
        
        logger.info(f"Querying analytics data from {start_date} to {end_date}")
        
        # Query analytics data
        analytics_query = f"""
        SELECT 
            user_id,
            product_id,
            transaction_id,
            amount,
            quantity,
            category,
            region,
            event_date,
            event_timestamp,
            attributes
        FROM `{project_id}.data_warehouse_{environment}.analytics_data`
        WHERE event_date >= '{start_date}'
        ORDER BY event_timestamp DESC
        LIMIT {limit}
        """
        
        analytics_results = client.query(analytics_query).result()
        analytics_data = [dict(row) for row in analytics_results]
        
        # Convert datetime objects to strings for JSON serialization
        for row in analytics_data:
            if 'event_date' in row and row['event_date']:
                row['event_date'] = row['event_date'].isoformat()
            if 'event_timestamp' in row and row['event_timestamp']:
                row['event_timestamp'] = row['event_timestamp'].isoformat()
        
        logger.info(f"Retrieved {len(analytics_data)} analytics records")
        
        # Query daily metrics
        metrics_query = f"""
        SELECT 
            metric_date,
            metric_name,
            dimension,
            value,
            count
        FROM `{project_id}.data_warehouse_{environment}.daily_metrics`
        WHERE metric_date >= '{start_date}'
        ORDER BY metric_date DESC, metric_name, dimension
        """
        
        metrics_results = client.query(metrics_query).result()
        metrics_data = [dict(row) for row in metrics_results]
        
        # Convert date objects to strings
        for row in metrics_data:
            if 'metric_date' in row and row['metric_date']:
                row['metric_date'] = row['metric_date'].isoformat()
        
        logger.info(f"Retrieved {len(metrics_data)} metrics records")
        
        # Get summary statistics
        summary_query = f"""
        SELECT 
            COUNT(*) as total_records,
            COUNT(DISTINCT user_id) as unique_users,
            COUNT(DISTINCT product_id) as unique_products,
            SUM(amount) as total_revenue,
            AVG(amount) as avg_transaction_amount,
            MAX(event_timestamp) as latest_event
        FROM `{project_id}.data_warehouse_{environment}.analytics_data`
        WHERE event_date >= '{start_date}'
        """
        
        summary_results = client.query(summary_query).result()
        summary_data = [dict(row) for row in summary_results][0]
        
        # Convert timestamp to string
        if 'latest_event' in summary_data and summary_data['latest_event']:
            summary_data['latest_event'] = summary_data['latest_event'].isoformat()
        
        logger.info(f"Summary: {summary_data}")
        
        # Prepare response
        response_data = {
            'success': True,
            'query_date': datetime.now().isoformat(),
            'date_range': {
                'start': start_date.isoformat(),
                'end': end_date.isoformat()
            },
            'summary': summary_data,
            'analytics_data': analytics_data,
            'daily_metrics': metrics_data
        }
        
        return (json.dumps(response_data), 200, headers)
        
    except Exception as e:
        logger.error(f"Error querying analytics: {str(e)}", exc_info=True)
        error_response = {
            'success': False,
            'error': str(e),
            'message': 'Failed to query analytics data'
        }
        return (json.dumps(error_response), 500, headers)
