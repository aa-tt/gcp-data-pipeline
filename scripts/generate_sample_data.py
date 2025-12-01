"""
Realistic Streaming Data Generator for GCP Data Pipeline

This script generates continuous realistic sample data streams for testing:
- E-commerce transactions
- User activity events
- IoT sensor data
- Application logs

Can run as:
1. One-time batch generation
2. Continuous streaming simulation
3. Load testing with configurable rates
"""

import argparse
import json
import random
import time
import uuid
from datetime import datetime, timedelta
from typing import Dict, List
import requests
from google.cloud import pubsub_v1


# ============================================================================
# Sample Data Generators
# ============================================================================

class DataGenerator:
    """Base class for generating realistic sample data"""
    
    def __init__(self):
        self.categories = ['electronics', 'clothing', 'home', 'sports', 'books', 'toys']
        self.regions = ['us-west', 'us-east', 'eu-west', 'ap-southeast', 'ap-northeast']
        self.products = self._generate_product_catalog()
        self.user_pool = [f"user-{str(uuid.uuid4())[:8]}" for _ in range(1000)]
        
    def _generate_product_catalog(self) -> Dict[str, List[Dict]]:
        """Generate a catalog of products"""
        catalog = {}
        for category in self.categories:
            catalog[category] = [
                {
                    'product_id': f"{category}-{i:04d}",
                    'name': f"{category.title()} Product {i}",
                    'base_price': round(random.uniform(10, 500), 2),
                    'category': category
                }
                for i in range(100)
            ]
        return catalog
    
    def generate_transaction(self) -> Dict:
        """Generate a realistic e-commerce transaction"""
        category = random.choice(self.categories)
        product = random.choice(self.products[category])
        quantity = random.randint(1, 5)
        
        # Add realistic price variations
        price_variation = random.uniform(0.9, 1.1)
        amount = round(product['base_price'] * price_variation * quantity, 2)
        
        return {
            'user_id': random.choice(self.user_pool),
            'product_id': product['product_id'],
            'product_name': product['name'],
            'amount': amount,
            'quantity': quantity,
            'category': category,
            'region': random.choice(self.regions),
            'payment_method': random.choice(['credit_card', 'debit_card', 'paypal', 'apple_pay']),
            'discount_applied': random.choice([True, False]),
            'timestamp': datetime.utcnow().isoformat()
        }
    
    def generate_user_activity(self) -> Dict:
        """Generate user activity event"""
        activities = ['page_view', 'search', 'add_to_cart', 'remove_from_cart', 'checkout_start']
        
        return {
            'user_id': random.choice(self.user_pool),
            'activity_type': random.choice(activities),
            'page_url': f"/products/{random.choice(self.categories)}",
            'session_id': str(uuid.uuid4()),
            'region': random.choice(self.regions),
            'device_type': random.choice(['mobile', 'desktop', 'tablet']),
            'timestamp': datetime.utcnow().isoformat()
        }
    
    def generate_iot_sensor_data(self) -> Dict:
        """Generate IoT sensor data"""
        device_id = f"sensor-{random.randint(1, 100):04d}"
        
        return {
            'device_id': device_id,
            'temperature': round(random.uniform(15, 35), 2),
            'humidity': round(random.uniform(30, 80), 2),
            'pressure': round(random.uniform(980, 1030), 2),
            'battery_level': round(random.uniform(0, 100), 1),
            'location': random.choice(self.regions),
            'status': random.choice(['online', 'online', 'online', 'warning']),  # 75% online
            'timestamp': datetime.utcnow().isoformat()
        }
    
    def generate_application_log(self) -> Dict:
        """Generate application log entry"""
        log_levels = ['INFO', 'INFO', 'INFO', 'WARNING', 'ERROR']  # Realistic distribution
        services = ['api-gateway', 'auth-service', 'payment-service', 'inventory-service']
        
        return {
            'service': random.choice(services),
            'log_level': random.choice(log_levels),
            'message': self._generate_log_message(),
            'request_id': str(uuid.uuid4()),
            'response_time_ms': random.randint(10, 2000),
            'status_code': random.choice([200, 200, 200, 201, 400, 404, 500]),
            'timestamp': datetime.utcnow().isoformat()
        }
    
    def _generate_log_message(self) -> str:
        """Generate realistic log message"""
        messages = [
            "Request processed successfully",
            "User authentication completed",
            "Payment processing initiated",
            "Database query executed",
            "Cache hit for key",
            "Rate limit check passed",
            "API endpoint called",
        ]
        return random.choice(messages)


# ============================================================================
# Data Publishers
# ============================================================================

class PubSubPublisher:
    """Publish data to GCP Pub/Sub"""
    
    def __init__(self, project_id: str, topic_name: str):
        self.publisher = pubsub_v1.PublisherClient()
        self.topic_path = self.publisher.topic_path(project_id, topic_name)
        
    def publish(self, data: Dict, data_type: str):
        """Publish a message to Pub/Sub"""
        message = {
            'id': str(uuid.uuid4()),
            'ingestion_timestamp': datetime.utcnow().isoformat(),
            'source_system': 'data-generator',
            'data_type': data_type,
            'raw_payload': json.dumps(data),
            'metadata': {
                'version': '1.0',
                'environment': 'test'
            }
        }
        
        message_bytes = json.dumps(message).encode('utf-8')
        future = self.publisher.publish(self.topic_path, message_bytes)
        return future.result()


class HTTPPublisher:
    """Publish data via HTTP to Cloud Function"""
    
    def __init__(self, function_url: str):
        self.function_url = function_url
        
    def publish(self, data: Dict, data_type: str):
        """Send data via HTTP POST"""
        payload = {
            'data_type': data_type,
            'source_system': 'data-generator',
            'payload': data
        }
        
        response = requests.post(
            self.function_url,
            json=payload,
            headers={'Content-Type': 'application/json'},
            timeout=10
        )
        return response.json()


# ============================================================================
# Stream Simulator
# ============================================================================

class StreamSimulator:
    """Simulate continuous data streams"""
    
    def __init__(self, publisher, generator: DataGenerator):
        self.publisher = publisher
        self.generator = generator
        
    def run_batch(self, count: int, data_type: str):
        """Generate and publish a batch of messages"""
        print(f"📊 Generating {count} {data_type} events...")
        
        success_count = 0
        for i in range(count):
            try:
                if data_type == 'transaction':
                    data = self.generator.generate_transaction()
                elif data_type == 'user_activity':
                    data = self.generator.generate_user_activity()
                elif data_type == 'iot_sensor':
                    data = self.generator.generate_iot_sensor_data()
                elif data_type == 'application_log':
                    data = self.generator.generate_application_log()
                else:
                    raise ValueError(f"Unknown data type: {data_type}")
                
                self.publisher.publish(data, data_type)
                success_count += 1
                
                if (i + 1) % 10 == 0:
                    print(f"  ✅ Published {i + 1}/{count} messages")
                    
            except Exception as e:
                print(f"  ❌ Error publishing message {i + 1}: {e}")
        
        print(f"✅ Batch complete: {success_count}/{count} messages published")
        return success_count
    
    def run_continuous(self, rate_per_second: float, data_type: str, duration_seconds: int = None):
        """Generate continuous stream at specified rate"""
        print(f"🔄 Starting continuous stream: {rate_per_second} {data_type}/sec")
        if duration_seconds:
            print(f"   Duration: {duration_seconds} seconds")
        else:
            print(f"   Duration: Infinite (Ctrl+C to stop)")
        
        interval = 1.0 / rate_per_second
        start_time = time.time()
        message_count = 0
        
        try:
            while True:
                if duration_seconds and (time.time() - start_time) > duration_seconds:
                    break
                
                try:
                    if data_type == 'transaction':
                        data = self.generator.generate_transaction()
                    elif data_type == 'user_activity':
                        data = self.generator.generate_user_activity()
                    elif data_type == 'iot_sensor':
                        data = self.generator.generate_iot_sensor_data()
                    elif data_type == 'application_log':
                        data = self.generator.generate_application_log()
                    else:
                        raise ValueError(f"Unknown data type: {data_type}")
                    
                    self.publisher.publish(data, data_type)
                    message_count += 1
                    
                    if message_count % 100 == 0:
                        elapsed = time.time() - start_time
                        actual_rate = message_count / elapsed
                        print(f"  📈 {message_count} messages sent ({actual_rate:.1f}/sec)")
                    
                    time.sleep(interval)
                    
                except Exception as e:
                    print(f"  ❌ Error: {e}")
                    
        except KeyboardInterrupt:
            print("\n⏹️  Stopping stream...")
        
        elapsed = time.time() - start_time
        print(f"✅ Stream complete: {message_count} messages in {elapsed:.1f}s ({message_count/elapsed:.1f}/sec)")
        return message_count
    
    def run_mixed_stream(self, rate_per_second: float, duration_seconds: int = None):
        """Generate mixed data types at specified rate"""
        print(f"🔄 Starting mixed stream: {rate_per_second} events/sec")
        
        data_types = ['transaction', 'user_activity', 'iot_sensor', 'application_log']
        weights = [0.4, 0.3, 0.2, 0.1]  # 40% transactions, 30% activities, 20% IoT, 10% logs
        
        interval = 1.0 / rate_per_second
        start_time = time.time()
        message_count = 0
        type_counts = {dt: 0 for dt in data_types}
        
        try:
            while True:
                if duration_seconds and (time.time() - start_time) > duration_seconds:
                    break
                
                try:
                    # Select data type based on weights
                    data_type = random.choices(data_types, weights=weights)[0]
                    
                    if data_type == 'transaction':
                        data = self.generator.generate_transaction()
                    elif data_type == 'user_activity':
                        data = self.generator.generate_user_activity()
                    elif data_type == 'iot_sensor':
                        data = self.generator.generate_iot_sensor_data()
                    else:
                        data = self.generator.generate_application_log()
                    
                    self.publisher.publish(data, data_type)
                    message_count += 1
                    type_counts[data_type] += 1
                    
                    if message_count % 100 == 0:
                        elapsed = time.time() - start_time
                        print(f"  📈 {message_count} messages ({', '.join(f'{k}: {v}' for k, v in type_counts.items())})")
                    
                    time.sleep(interval)
                    
                except Exception as e:
                    print(f"  ❌ Error: {e}")
                    
        except KeyboardInterrupt:
            print("\n⏹️  Stopping stream...")
        
        elapsed = time.time() - start_time
        print(f"✅ Stream complete: {message_count} messages in {elapsed:.1f}s")
        print(f"   Breakdown: {json.dumps(type_counts, indent=2)}")
        return message_count


# ============================================================================
# Main CLI
# ============================================================================

def main():
    parser = argparse.ArgumentParser(description='Generate streaming sample data for GCP Pipeline')
    
    # Connection settings
    parser.add_argument('--mode', choices=['pubsub', 'http'], default='http',
                        help='Publishing mode (default: http)')
    parser.add_argument('--project-id', help='GCP Project ID (for Pub/Sub mode)')
    parser.add_argument('--topic', default='raw-data-topic-dev',
                        help='Pub/Sub topic name (default: raw-data-topic-dev)')
    parser.add_argument('--function-url', help='Cloud Function URL (for HTTP mode)')
    
    # Data generation settings
    parser.add_argument('--type', choices=['transaction', 'user_activity', 'iot_sensor', 'application_log', 'mixed'],
                        default='transaction', help='Type of data to generate')
    parser.add_argument('--stream', action='store_true',
                        help='Run in continuous streaming mode')
    parser.add_argument('--count', type=int, default=100,
                        help='Number of messages for batch mode (default: 100)')
    parser.add_argument('--rate', type=float, default=10.0,
                        help='Messages per second for stream mode (default: 10)')
    parser.add_argument('--duration', type=int,
                        help='Duration in seconds (for stream mode)')
    
    args = parser.parse_args()
    
    # Initialize generator
    generator = DataGenerator()
    
    # Initialize publisher
    if args.mode == 'pubsub':
        if not args.project_id:
            print("❌ Error: --project-id required for Pub/Sub mode")
            return
        publisher = PubSubPublisher(args.project_id, args.topic)
    else:  # HTTP mode
        if not args.function_url:
            print("❌ Error: --function-url required for HTTP mode")
            return
        publisher = HTTPPublisher(args.function_url)
    
    # Initialize simulator
    simulator = StreamSimulator(publisher, generator)
    
    # Run simulation
    if args.stream:
        if args.type == 'mixed':
            simulator.run_mixed_stream(args.rate, args.duration)
        else:
            simulator.run_continuous(args.rate, args.type, args.duration)
    else:
        simulator.run_batch(args.count, args.type)


if __name__ == '__main__':
    main()
