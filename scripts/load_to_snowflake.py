"""
Load synthetic data to Snowflake programmatically
Used for Airflow DAG or local automation
"""

import os
import json
import csv
from pathlib import Path
from typing import List, Dict
import snowflake.connector
from snowflake.connector import DictCursor
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

SNOWFLAKE_CONFIG = {
    "account": os.getenv("SNOWFLAKE_ACCOUNT"),
    "user": os.getenv("SNOWFLAKE_USER"),
    "password": os.getenv("SNOWFLAKE_PASSWORD"),
    "warehouse": os.getenv("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH"),
    "database": "media_analytics",
    "schema": "raw",
    "role": os.getenv("SNOWFLAKE_ROLE", "ACCOUNTADMIN")
}


def get_connection():
    """Create Snowflake connection"""
    return snowflake.connector.connect(
        account=SNOWFLAKE_CONFIG["account"],
        user=SNOWFLAKE_CONFIG["user"],
        password=SNOWFLAKE_CONFIG["password"],
        warehouse=SNOWFLAKE_CONFIG["warehouse"],
        database=SNOWFLAKE_CONFIG["database"],
        schema=SNOWFLAKE_CONFIG["schema"],
        role=SNOWFLAKE_CONFIG["role"]
    )


def load_writers(conn, data_dir: Path):
    """Load writer metadata from CSV"""
    print("Loading writer_metadata...")
    
    with open(data_dir / "writers.csv", "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        writers = list(reader)
    
    cursor = conn.cursor()
    
    # Truncate table (optional - remove if appending)
    cursor.execute("TRUNCATE TABLE writer_metadata")
    
    # Bulk insert
    insert_sql = """
    INSERT INTO writer_metadata (
        writer_id, writer_name, primary_category, 
        tenure_start_date, contract_type, target_articles_per_month
    ) VALUES (%s, %s, %s, %s, %s, %s)
    """
    
    rows = [
        (
            w["writer_id"],
            w["writer_name"],
            w["primary_category"],
            w["tenure_start_date"],
            w["contract_type"],
            int(w["target_articles_per_month"])
        )
        for w in writers
    ]
    
    cursor.executemany(insert_sql, rows)
    conn.commit()
    
    print(f"  ✓ Loaded {len(rows)} writers")
    
    cursor.close()


def load_articles(conn, data_dir: Path):
    """Load article metadata from CSV"""
    print("Loading article_metadata...")
    
    with open(data_dir / "articles.csv", "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        articles = list(reader)
    
    cursor = conn.cursor()
    
    # Truncate table
    cursor.execute("TRUNCATE TABLE article_metadata")
    
    # Bulk insert
    insert_sql = """
    INSERT INTO article_metadata (
        article_id, title, writer_id, publish_date, 
        category, word_count, is_premium, estimated_rpm
    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
    """
    
    rows = [
        (
            a["article_id"],
            a["title"],
            a["writer_id"],
            a["publish_date"],
            a["category"],
            int(a["word_count"]),
            a["is_premium"].lower() == "true",
            float(a["estimated_rpm"])
        )
        for a in articles
    ]
    
    cursor.executemany(insert_sql, rows)
    conn.commit()
    
    print(f"  ✓ Loaded {len(rows)} articles")
    
    cursor.close()


def load_events(conn, data_dir: Path):
    """Load events from JSONL file"""
    print("Loading events_raw... (this may take a few minutes)")
    
    cursor = conn.cursor()
    
    # Truncate table
    cursor.execute("TRUNCATE TABLE events_raw")
    
    # Read JSONL and prepare for bulk insert
    # Note: For very large files, consider using Snowflake stage + COPY INTO
    insert_sql = """
    INSERT INTO events_raw (
        event_date, event_timestamp, event_name, 
        user_pseudo_id, ga_session_id, event_params,
        device, geo, traffic_source
    ) 
    SELECT 
        PARSE_JSON(%s):event_date::STRING,
        PARSE_JSON(%s):event_timestamp::NUMBER,
        PARSE_JSON(%s):event_name::STRING,
        PARSE_JSON(%s):user_pseudo_id::STRING,
        PARSE_JSON(%s):ga_session_id::STRING,
        PARSE_JSON(%s):event_params::VARIANT,
        PARSE_JSON(%s):device::OBJECT,
        PARSE_JSON(%s):geo::OBJECT,
        PARSE_JSON(%s):traffic_source::OBJECT
    """
    
    events = []
    with open(data_dir / "events.jsonl", "r", encoding="utf-8") as f:
        for i, line in enumerate(f):
            if i % 50000 == 0 and i > 0:
                print(f"  Processing event {i}...")
            event = line.strip()
            if event:
                events.append((event,) * 9)  # Tuple with same JSON string 9 times
    
    # Insert in batches of 10K for performance
    batch_size = 10000
    for i in range(0, len(events), batch_size):
        batch = events[i:i+batch_size]
        cursor.executemany(insert_sql, batch)
        if i % 50000 == 0:
            print(f"  Inserted {i + len(batch)} events...")
    
    conn.commit()
    
    print(f"  ✓ Loaded {len(events)} events")
    
    cursor.close()


def validate_load(conn):
    """Run validation queries after load"""
    print("\nValidating data load...")
    
    cursor = conn.cursor(DictCursor)
    
    # Check row counts
    queries = {
        "writers": "SELECT COUNT(*) as cnt FROM writer_metadata",
        "articles": "SELECT COUNT(*) as cnt FROM article_metadata",
        "events": "SELECT COUNT(*) as cnt FROM events_raw"
    }
    
    for table, query in queries.items():
        cursor.execute(query)
        result = cursor.fetchone()
        print(f"  {table}: {result['CNT']:,} rows")
    
    # Check referential integrity
    cursor.execute("""
        SELECT COUNT(DISTINCT a.writer_id) - COUNT(DISTINCT w.writer_id) as orphans
        FROM article_metadata a
        LEFT JOIN writer_metadata w ON a.writer_id = w.writer_id
    """)
    result = cursor.fetchone()
    if result["ORPHANS"] == 0:
        print("  ✓ Referential integrity validated")
    else:
        print(f"  ⚠ Warning: {result['ORPHANS']} articles with invalid writer_id")
    
    # Check event distribution
    cursor.execute("""
        SELECT event_name, COUNT(*) as cnt
        FROM events_raw
        GROUP BY event_name
        ORDER BY cnt DESC
    """)
    print("\n  Event distribution:")
    for row in cursor.fetchall():
        print(f"    {row['EVENT_NAME']}: {row['CNT']:,}")
    
    cursor.close()


def main():
    """Main execution"""
    data_dir = Path("./data")
    
    if not data_dir.exists():
        print(f"Error: Data directory not found: {data_dir}")
        print("Run generate_synthetic_data.py first")
        return
    
    print("=" * 60)
    print("Snowflake Data Loader")
    print("=" * 60)
    print(f"Account: {SNOWFLAKE_CONFIG['account']}")
    print(f"Database: {SNOWFLAKE_CONFIG['database']}")
    print(f"Schema: {SNOWFLAKE_CONFIG['schema']}")
    print()
    
    try:
        # Connect
        print("Connecting to Snowflake...")
        conn = get_connection()
        print("  ✓ Connected")
        
        # Load data
        load_writers(conn, data_dir)
        load_articles(conn, data_dir)
        load_events(conn, data_dir)
        
        # Validate
        validate_load(conn)
        
        print("\n" + "=" * 60)
        print("✓ Data loading complete!")
        print("=" * 60)
        print("\nNext steps:")
        print("1. Run: dbt run (to transform data)")
        print("2. Check Snowflake for tables in media_analytics.raw schema")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        raise
    
    finally:
        if 'conn' in locals():
            conn.close()


if __name__ == "__main__":
    main()
