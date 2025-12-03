"""
PySpark ETL Job for Data Transformation
Runs on Dataproc Serverless

This job demonstrates:
1. Reading data from Cloud Storage or BigQuery
2. Performing transformations using Spark
3. Writing results to BigQuery and/or Cloud Storage
"""

import argparse
import logging
from datetime import datetime, timedelta
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import *

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class DataETL:
    """Main ETL class for data transformation"""
    
    def __init__(self, project_id, environment, date):
        self.project_id = project_id
        self.environment = environment
        self.date = date
        self.spark = self._create_spark_session()
        
    def _create_spark_session(self):
        """Create Spark session with required configurations"""
        return (SparkSession.builder
                .appName(f"DataETL-{self.environment}-{self.date}")
                .config("spark.sql.adaptive.enabled", "true")
                .config("spark.sql.adaptive.coalescePartitions.enabled", "true")
                .getOrCreate())
    
    def read_raw_data(self, source_type="bigquery", source_path=None):
        """
        Read raw data from source
        
        Args:
            source_type: 'bigquery' or 'gcs'
            source_path: Path to data (table name or GCS path)
        """
        logger.info(f"Reading data from {source_type}: {source_path}")
        
        if source_type == "bigquery":
            # Read from BigQuery
            df = (self.spark.read
                  .format("bigquery")
                  .option("table", source_path)
                  .load())
        elif source_type == "gcs":
            # Read from Cloud Storage (JSON, Parquet, CSV, etc.)
            if source_path.endswith('.json') or '*.json' in source_path:
                # For multiline JSON (pretty-printed), need multiLine option
                df = self.spark.read.option("multiLine", "true").json(source_path)
            elif source_path.endswith('.parquet'):
                df = self.spark.read.parquet(source_path)
            elif source_path.endswith('.csv'):
                df = self.spark.read.csv(source_path, header=True, inferSchema=True)
            else:
                df = self.spark.read.option("multiLine", "true").json(source_path)
        else:
            raise ValueError(f"Unsupported source type: {source_type}")
        
        logger.info(f"Read {df.count()} records")
        return df
    
    def transform_data(self, df):
        """
        Apply transformations to the data
        
        Example transformations:
        - Parse JSON fields
        - Filter invalid records
        - Aggregate data
        - Enrich with additional data
        """
        logger.info("Starting data transformation")
        
        # The JSON files from GCS have structure: {id, processed_timestamp, data_type, data: {...}, metadata}
        # Extract fields from the nested 'data' field
        if 'data' in df.columns:
            # Convert the entire data struct to JSON string, then parse it back to access fields safely
            df = df.withColumn("data_json", F.to_json(F.col("data")))
            
            # Extract fields using JSON path - these return NULL if field doesn't exist
            df = df.select(
                F.col("id"),
                F.col("ingestion_timestamp"),
                F.col("source_system"),
                F.col("data_type"),
                F.get_json_object(F.col("data_json"), "$.user_id").alias("user_id"),
                F.get_json_object(F.col("data_json"), "$.product_id").alias("product_id"),
                F.get_json_object(F.col("data_json"), "$.transaction_id").alias("transaction_id"),
                F.get_json_object(F.col("data_json"), "$.amount").cast("double").alias("amount"),
                F.get_json_object(F.col("data_json"), "$.quantity").cast("int").alias("quantity"),
                F.get_json_object(F.col("data_json"), "$.category").alias("category"),
                F.get_json_object(F.col("data_json"), "$.region").alias("region")
            )
        
        # Add event date and timestamp
        # IMPORTANT: Convert ingestion_timestamp string to proper timestamp type
        # BigQuery expects TIMESTAMP type, not STRING. Use F.to_timestamp() for conversion.
        # This prevents schema mismatch errors when writing to BigQuery.
        df = df.withColumn("event_timestamp", F.to_timestamp(F.col("ingestion_timestamp")))
        df = df.withColumn("event_date", F.to_date(F.col("event_timestamp")))
        
        # Filter out records without amount (keep only transaction-like events)
        # For this example, we only process events with amount
        df = df.filter(
            (F.col("amount").isNotNull()) &
            (F.col("amount") > 0)
        )
        
        # Add additional attributes as JSON
        # NOTE: F.to_json() creates a STRING, not JSON type in BigQuery
        # The BigQuery table schema should use STRING type for attributes field
        df = df.withColumn("attributes", F.to_json(
            F.struct(
                F.col("source_system"),
                F.col("data_type")
            )
        ))
        
        # Select final columns
        df = df.select(
            "event_date",
            "event_timestamp",
            "user_id",
            "product_id",
            "transaction_id",
            "category",
            "region",
            "amount",
            "quantity",
            "attributes"
        )
        
        logger.info(f"Transformation complete. Output records: {df.count()}")
        return df
    
    def aggregate_metrics(self, df):
        """
        Create aggregated metrics
        """
        logger.info("Generating aggregated metrics")
        
        metrics = df.groupBy("event_date", "category", "region").agg(
            F.sum("amount").alias("total_amount"),
            F.sum("quantity").alias("total_quantity"),
            F.count("*").alias("record_count"),
            F.avg("amount").alias("avg_amount"),
            F.min("event_timestamp").alias("first_event"),
            F.max("event_timestamp").alias("last_event")
        )
        
        # Reshape for metrics table
        metrics_long = metrics.select(
            F.col("event_date").alias("metric_date"),
            F.lit("total_amount").alias("metric_name"),
            F.concat(F.col("category"), F.lit("-"), F.col("region")).alias("dimension"),
            F.col("total_amount").alias("value"),
            F.col("record_count").alias("count")
        )
        
        logger.info(f"Generated {metrics_long.count()} metric records")
        return metrics_long
    
    def write_to_bigquery(self, df, table_name, write_mode="append"):
        """
        Write data to BigQuery
        
        Args:
            df: DataFrame to write
            table_name: Target table name (dataset.table)
            write_mode: 'append', 'overwrite', or 'ignore'
        """
        logger.info(f"Writing to BigQuery table: {table_name}")
        
        (df.write
         .format("bigquery")
         .option("table", table_name)
         .option("temporaryGcsBucket", f"{self.project_id}-staging-{self.environment}")
         .mode(write_mode)
         .save())
        
        logger.info("Write to BigQuery complete")
    
    def write_to_gcs(self, df, gcs_path, format_type="parquet", partition_by=None):
        """
        Write data to Cloud Storage
        
        Args:
            df: DataFrame to write
            gcs_path: GCS path (gs://bucket/path)
            format_type: 'parquet', 'json', 'csv'
            partition_by: Column(s) to partition by
        """
        logger.info(f"Writing to GCS: {gcs_path}")
        
        writer = df.write.mode("overwrite")
        
        if partition_by:
            writer = writer.partitionBy(partition_by)
        
        if format_type == "parquet":
            writer.parquet(gcs_path)
        elif format_type == "json":
            writer.json(gcs_path)
        elif format_type == "csv":
            writer.csv(gcs_path, header=True)
        
        logger.info("Write to GCS complete")
    
    def run(self):
        """Execute the full ETL pipeline"""
        try:
            logger.info(f"Starting ETL job for date: {self.date}")
            
            # Step 1: Read raw data from GCS (processed JSON files)
            gcs_input_path = f"gs://{self.project_id}-processed-data-{self.environment}/processed/*/{self.date.replace('-', '/')}/*.json"
            logger.info(f"Reading from GCS: {gcs_input_path}")
            raw_df = self.read_raw_data("gcs", gcs_input_path)
            
            # Step 2: Transform data
            transformed_df = self.transform_data(raw_df)
            
            # Step 3: Write transformed data to BigQuery analytics table
            analytics_table = f"{self.project_id}.data_warehouse_{self.environment}.analytics_data"
            self.write_to_bigquery(transformed_df, analytics_table, write_mode="append")
            
            # Step 4: Write to GCS for backup
            gcs_output_path = f"gs://{self.project_id}-processed-data-{self.environment}/analytics/{self.date}"
            self.write_to_gcs(transformed_df, gcs_output_path, format_type="parquet", partition_by="event_date")
            
            # Step 5: Generate and write aggregated metrics
            metrics_df = self.aggregate_metrics(transformed_df)
            metrics_table = f"{self.project_id}.data_warehouse_{self.environment}.daily_metrics"
            self.write_to_bigquery(metrics_df, metrics_table, write_mode="append")
            
            logger.info("ETL job completed successfully")
            
        except Exception as e:
            logger.error(f"ETL job failed: {str(e)}", exc_info=True)
            raise
        finally:
            self.spark.stop()


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Data ETL PySpark Job")
    parser.add_argument("--project-id", required=True, help="GCP Project ID")
    parser.add_argument("--environment", default="dev", help="Environment (dev/staging/prod)")
    parser.add_argument("--date", help="Date to process (YYYY-MM-DD), defaults to yesterday")
    
    args = parser.parse_args()
    
    # Default to yesterday if no date specified
    if not args.date:
        yesterday = datetime.now() - timedelta(days=1)
        args.date = yesterday.strftime("%Y-%m-%d")
    
    logger.info(f"Starting ETL job with parameters: {args}")
    
    # Create and run ETL
    etl = DataETL(
        project_id=args.project_id,
        environment=args.environment,
        date=args.date
    )
    etl.run()


if __name__ == "__main__":
    main()
